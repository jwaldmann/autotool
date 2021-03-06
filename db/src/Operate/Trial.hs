-- | standalone aufgabenconfig,
-- damit jeder mal tutor spielen kann

{-# language PatternSignatures #-}

module Main where

import Gateway.CGI

import qualified Default

import Inter.Evaluate

import Types.Basic
import Types.TaskTree
import Types.Version
import Types.ServerInfo
import Types.TaskDescription
import qualified Types.Documented as D
import qualified Types.Signed as S
import Types.Solution
import Types.Config

import Service.Interface

import Operate.Make 
import Operate.Motd
import Operate.Bank
import Operate.Store 
import Operate.Login
import Operate.Logged


import Operate.Tutor
import Operate.Student
import Operate.Types ( make )

import qualified Control.Aufgabe.DB
import qualified Operate.Param as P
import qualified Operate.Statistik

import Gateway.Help

import Autolib.Multilingual ( Language (..), specialize )

import Autolib.Set
import qualified Autolib.Output
import qualified Autolib.Output as O


import qualified Network.CGI

import Control.Types 
    ( toString, fromCGI, Name, Typ , Remark, HiLo (..), Status (..)
    , Oks (..), Nos (..), Time , Wert (..), MNr, SNr, VNr, ANr (..), UNr
    , TimeStatus (..)
    )

import qualified Control.Types   


import Challenger.Partial
import Inter.Types
import Operate.Common

import Control.Student.CGI
import Control.Vorlesung.DB
import qualified Control.Student.DB
import qualified Control.Punkt
import qualified Control.Stud_Aufg.DB

import qualified Control.Aufgabe as A
import qualified Control.Stud_Aufg as SA
import qualified Control.Student as S
import qualified Control.Vorlesung as V
import qualified Control.Gruppe as G
import qualified Control.Stud_Grp as SG
import qualified Control.Schule as U

import Control.Types ( VNr (..) )

import Autolib.Reporter.Type hiding ( wrap, initial )
import Autolib.ToDoc
import qualified Autolib.Output as O
import Autolib.Reader
import Autolib.Util.Sort
import Autolib.FiniteMap

import qualified Util.Datei as D
import Debug

import System.Random
import System.Directory
import Data.Typeable
import Data.Maybe
import Data.Tree
import Data.List ( partition )
import Control.Monad

import qualified Gateway.Html as Html

import qualified Autolib.Multilingual as M
import qualified Autolib.Multilingual.Html as H

import Operate.DateTime ( defaults )

main :: IO ()
main = Gateway.CGI.execute ( Default.trial_cgi_name ) $ do
   wrap $ do -- FIXME: following code looks ugly
       mtopic <- look "topic"
       case mtopic of
           Just topic -> fixed_topic Default.server topic
	   Nothing -> do
	       mproblem <- look "problem"
	       case mproblem of
	           Just problem -> fixed_problem problem
		   Nothing -> do
                     mlecture <- look "lecture"
                     case mlecture of
                       Just lecture -> fixed_lecture Default.server lecture
                       Nothing -> free_choice Default.server

free_choice server = do
       btabled $ select_preferred_language 
       selektor server
       con <- io $ Operate.Motd.contents
       html con
       hr

btabled :: Monad m => Form m a -> Form m a
btabled = bracketed btable
rowed :: Monad m => Form m a -> Form m a
rowed = bracketed row
mutexed :: ( Typeable a, Monad m ) => Form m () -> Form m a
mutexed action = do begin ; action ; end
bracketed b action = do open b; x <- action ; close ; return x

selektor server = do
    hr
    h2 "(Tutor) Aufgabe auswählen und konfigurieren"
    hr
    -- let tmk = Inter.Collector.tmakers
    -- tasks <- io $ get_task_types server
    action <- btabled $ click_choice "Auswahl..." 
        [ ( "nach Vorlesungen", vor server )
	, ( "nach Themen" , aufgaben server)
	]
    action dummy

dummy = ( S.Student { }, VNr 42, True )   

vor server pack = do
    schulen <- io $ U.get
    schule <- btabled $ click_choice "Hochschule" $ do
        u <- schulen
	return ( toString $ U.name u , u )
    vors <- io $ V.get_at_school $ U.unr schule
    vor <- btabled $ click_choice "Vorlesung" $ do
        v <- vors
	return ( toString $ V.name v , v )
    lecture server vor pack
    
fixed_lecture server vor = do
    btabled $ select_preferred_language 
    vs <- io $ V.get_this $ fromCGI vor
    case vs of
        [ v ] -> lecture server v dummy
        _ -> fail "keine Vorlesung mit dieser Nummer" 

lecture server vor pack = do    
    h3 $ "Vorlesung: " ++ ( toString $ V.name vor )
    plain "Link zu dieser Vorlesung:"
    let lect = "Trial.cgi?lecture=" 
                    ++ Control.Types.toString ( V.vnr vor )
    html $ specialize Autolib.Multilingual.DE  
	     $ ( O.render $ O.Link $ lect :: H.Html )

    aufgaben <- io $ A.get ( Just $ V.vnr vor )
    ( conf, auf ) <- mutexed $ btabled $ do
	rowed $ do plain "Aufgabe" ; plain "Typ"
	sequence_ $ do
	    auf <- filter ( \ a -> Early /= A.timeStatus a ) aufgaben
	    return $ rowed $ do
	        plain $ toString $ A.name auf
		plain $ toString $ A.typ  auf
		click ( "solve" , ( False, auf ) )
		click ( "config and solve", ( True, auf ) )
                let  dump = "Dump.cgi?problem=" ++ Control.Types.toString (A.anr auf)
                html $ specialize Autolib.Multilingual.DE
                     $ ( O.render $ O.Link dump :: H.Html )
    common_aufgaben server pack ( Just auf ) conf   

fixed_problem problem = do
    btabled $ select_preferred_language 
    [ auf ] <- io $ Control.Aufgabe.DB.get_this $ fromCGI problem
    open btable -- ?
    common_aufgaben Default.server dummy ( Just auf ) False

fixed_topic server topic = do
  {-
    let mks =  do Right mk <- flatten Inter.Collector.tmakers ; return mk
    mk : _ <- return $ do 
	 mk @ ( Make _ doc _ _ _ ) <- mks
	 guard $ doc == topic
	 return mk
-}
    btabled $ select_preferred_language 
    open btable -- ?
    let mk = make server topic
    common_aufgaben_trailer dummy Nothing True server mk False

-----------------------------------------------------------------------------

aufgaben server pack = do
    common_aufgaben server pack Nothing True

common_aufgaben server svt @ ( stud, vnr, tutor ) mauf conf = do
    -- plain $ "common_aufgaben.conf: " ++ show conf
    -- let mks = do Right mk <- flatten tmk ; return mk
    ( mk, type_click ) <- find_mk server conf mauf
    -- if the user chose a new type, ignore any predetermined configuration
    let mauf' = if type_click then Nothing else mauf
    common_aufgaben_trailer svt mauf' conf server mk type_click

-- | three use cases:
-- "solve": task type and task instance is known. (mauf = Just .., conf = True)
-- "select": task type is unknown (type_click = True)
-- "config and solve": task type is known, task instances is unknown (conf = True)
common_aufgaben_trailer ( stud, vnr, tutor ) mauf conf server mk type_click = do
    -- plain $ "common_aufgaben_trailer.conf: " ++ show conf
    -- plain $ "common_aufgaben_trailer.type_click: " ++ show type_click
    auf' <- case ( mauf, conf ) of
	 ( Just auf, False ) | not type_click -> return auf
         ( Just auf, True ) -> 
              edit_aufgabe_extra server mk mauf    vnr Nothing type_click
                                 ( \ a -> Early /= A.timeStatus a )
	 _ -> edit_aufgabe_extra server mk Nothing vnr Nothing type_click
                                 ( \ a -> Early /= A.timeStatus a )
    stud' <- get_stud tutor stud
    hr
    h2 "(Student) Aufgabe lösen"
    hr
    ( minst :: Maybe O.Output, cs, res, com :: Maybe H.Html ) 
        <- solution vnr Nothing stud'  auf' 
    scores <- scores_link
    hr

    plain "Link zu diesem Aufgabentyp:"
    let target = 
          "Trial.cgi?topic=" ++ Network.CGI.urlEncode (show mk)
    html $ specialize Autolib.Multilingual.DE  
	 $ ( O.render $ O.Link $ target :: H.Html )
    hr

    case mauf of
      Just auf | A.anr auf' /= ANr 0 -> do
        plain "Link zu dieser Aufgabeninstanz:"
        let problem = "Trial.cgi?problem=" 
                    ++ Control.Types.toString ( A.anr auf' )
        html $ specialize Autolib.Multilingual.DE  
	     $ ( O.render $ O.Link $ problem :: H.Html )
      _ -> return ()

    footer scores




