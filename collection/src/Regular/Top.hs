{-# language FlexibleInstances #-}
{-# language FlexibleContexts #-}
{-# language MultiParamTypeClasses #-}
{-# language DeriveDataTypeable #-}
{-# language TemplateHaskell #-}
{-# language DatatypeContexts #-}
{-# language ScopedTypeVariables #-}
{-# language DeriveDataTypeable #-}

module Regular.Top where

import Regular.Type

import Autolib.NFA.Eq


import Autolib.NFA ( NFA )
import qualified NFA.Property

import Autolib.Exp ( RX )
import qualified Exp.Property
import qualified Autolib.Exp.Inter as E

import qualified Autolib.Logic.Formula.FO as L
import qualified Regular.Logic as L

import qualified Grammatik as G
import qualified Grammatik.Property as G

import Inter.Types

import Autolib.ToDoc
import Autolib.Reader
import Autolib.Hash

import qualified Challenger as C

import Data.Typeable
import Autolib.Reporter
import Autolib.Informed
import Autolib.Size

data Regular from to = Regular
    deriving ( Eq, Ord, Show, Read, Typeable )

instance OrderScore ( Regular from to ) where
    scoringOrder _ = Increasing

data (RegularC from, RegularC to ) => Config from to = Config from [ Property to ] deriving (   Typeable )

derives [makeReader, makeToDoc] [''Config]

instance ( RegularC from, RegularC to ) => C.Verify ( Regular from to ) (Config from to) where
    verify p ( Config given spec ) = return ()

instance ( RegularC from, RegularC to ) => C.Partial ( Regular from to ) ( Config from to) to where

    report p  ( Config given spec :: Config from to )  = do
        inform $ vcat
            [ text "Gegeben ist" <+> bestimmt given , nest 4 $ toDoc given ]
        inform $ vcat 
            [ text "Gesucht ist" <+> unbestimmt ( undefined :: to )
            , text "mit folgenden Eigenschaften"
            , nest 4 $ vcat (map toDoc spec)
            ]

    initial p ( Config given props  ) = 
        Regular.Type.initial  props

    partial p ( Config from props ) to = do
        validate props to

    total p ( Config from props  ) to = do
        alpha <- alphabet ( to `asTypeOf` undefined ) props 
        flag <- nested 4 $ do
             f <- semantics alpha from
             t <- semantics alpha to
             equ ( informed ( text "Sprache der Aufgabenstellung" ) f )
                 ( informed ( text "Sprache Ihrer Einsendung" ) t )
        when (not flag) $ reject $ text ""


instance ( RegularC from, RegularC to, Size to ) => C.Measure ( Regular from to ) ( Config from to ) to where
    measure p (Config from props ) to = fromIntegral $ size to


make :: (  RegularC to, RegularC from)
     => String 
     -> Config from to  
     -> Make
make tag (conf :: Config from to) = 
    let t = "Regular" ++ "." ++ tag
    in  Make (Regular :: Regular from to) t
        ( \ inst -> Var
            { problem = Regular 
            , tag = t
            , key = \ matrikel -> return matrikel
            , generate = \ salt cachefun -> 
                  return $ return inst
            } :: Var (Regular from to)
                     (Config from to)
                     to
        ) ( \ _con -> return () ) -- verify
        conf

make_exp2nfa :: Make
make_exp2nfa = make "exp2nfa"
    ( Config (read  "a (a+b)^* b" )
             NFA.Property.example 
       :: Config (RX Char) (NFA Char Int) )

make_nfa2exp :: Make
make_nfa2exp = make "nfa2exp"
    ( Config (E.inter E.std $ read  "a (a+b)^* b" )
             Exp.Property.example 
       :: Config (NFA Char Int) (RX Char) )

make_exp2fo :: Make
make_exp2fo = make "exp2fo"
    ( Config (read  "a (a+b)^* b" )
             L.example 
       :: Config (RX Char) (L.Formula) )

make_fo2exp :: Make
make_fo2exp = make "fo2exp"
    ( Config ( read "exists p : exists q : p < q && a(p) && b(q)" )
             Exp.Property.example 
       :: Config (L.Formula) (RX Char) )

make_exp2gram :: Make
make_exp2gram = make "exp2gram"
    ( Config (read  "a (a+b)^* b" )
            [ G.Rechtslinear ] 
       :: Config (RX Char) G.Grammatik )

make_gram2exp :: Make
make_gram2exp = make "gram2exp"
    ( Config G.example3 
             Exp.Property.example 
       :: Config G.Grammatik (RX Char) )
