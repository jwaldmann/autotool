module Control.Schule.DB where

--  $Id$

import Control.SQL
import Control.Types
import Control.Schule.Typ
import qualified Control.Student.Type as CST
import qualified Control.Student.DB

import Autolib.Multilingual ( Language (..))

import Prelude hiding ( all )

-- | get alle Schulen aus DB
-- TODO: implementiere filter
get :: IO [ Schule ]
get = get_from_where (  map reed [ "schule" ] ) $ ands []

get_unr :: UNr -> IO [ Schule ]
get_unr u = get_from_where 
     (  map reed [ "schule" ] ) 
     ( equals ( reed "schule.UNr" ) ( toEx u ) )


get_from_where f w = do
    conn <- myconnect
    stat <- squery conn $ Query qq
        [ From f , Where w ]
    res <- common stat
    disconnect conn
    return res

qq =  Select 
     $ map reed [ "schule.UNr as UNr" 
		, "schule.Name as Name"
                , "schule.Mail_Suffix as Mail_Suffix"
                , "schule.Use_Shibboleth as Use_Shibboleth"
                , "schule.Preferred_Language as Preferred_Language"
		] 

common = collectRows $ \ state -> do
    	g_unr <- getFieldValue state "UNr"
        g_name <- getFieldValue state "Name"
        g_mail_suffix <- getFieldValue state "Mail_Suffix"
        g_use_shibboleth <- getFieldValue state "Use_Shibboleth"
        g_preferred_language <- getFieldValue state "Preferred_Language"
        return $ Schule { unr = g_unr
			 , name = g_name
                         , mail_suffix = g_mail_suffix
                         , use_shibboleth = 0 /= ( g_use_shibboleth :: Int )
                         , preferred_language = g_preferred_language 
    			 }

-- | put into table:
put :: Maybe UNr
    -> Schule
    -> IO ()
put munr vor = do
    conn <- myconnect 
    let common = [ ( reed "Name", toEx $ name vor )
		 , ( reed "Mail_Suffix", toEx $ mail_suffix vor )
                 , ( reed "Use_Shibboleth", toEx $ use_shibboleth vor )
                 , ( reed "Preferred_Language", toEx $ preferred_language vor )
		 ]
    case munr of
	 Nothing -> squery conn $ Query
            ( Insert (reed "schule") common ) 
	    [ ]
         Just unr -> squery conn $ Query
            ( Update (reed "schule") common ) 
	    [ Where $ equals ( reed "schule.UNr" ) ( toEx unr ) ]
    disconnect conn

-- | delete
delete :: UNr
    -> IO ()
delete unr = do
    conn <- myconnect 
    squery conn $ Query
        ( Delete ( reed "schule" ) )
	[ Where $ equals ( reed "schule.UNr" ) ( toEx unr ) ]
    disconnect conn

