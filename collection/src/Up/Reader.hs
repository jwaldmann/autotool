module Up.Reader where

import Up.Data
import Up.ToDoc 

import Autolib.Reader

import Control.Applicative ( (<$>), (<*>) )
import Control.Monad ( guard )

instance Reader Name where
    reader = Name <$> do
         n <- my_identifier     
         guard $ not $ n `elem` reserved
         return n

reserved = [ "int", "bool", "unit", "Func" ]
    
instance Reader Typ where
 reader =  do my_reserved "unit" ; return TUnit
  <|> do my_reserved "int" ; return TInt
  <|> do my_reserved "bool" ; return TBool
  <|> do my_reserved "Func" 
         my_angles $ TFunc <$> my_commaSep reader

instance Reader TypedName where
    reader = TypedName <$> reader <*> reader

instance Reader Statement where
   reader = 
      try ( do tn <- reader ; my_symbol "=" ; e <- reader ; my_semi ; return $ Declaration tn e )
    <|> ( do s <- reader ; my_semi ; return $ Statement s )

instance Reader Exp where
    reader = do
        f <- atom
        args <- many $ my_parens $ my_commaSep reader
        return $ foldl App f args

atom :: Parser Exp
atom = ( ConstInteger <$> my_integer )
     <|> ( Ref <$> reader )
      <|> try (do ps <- my_parens $ my_commaSep reader
                  my_symbol "=>"
                  b <- reader 
                  return $ Program ps b )
    
instance Reader Block where
    reader = my_braces $ Block <$> many reader

{-

data Exp = ConstInteger Integer
         | Program { parameters :: [ TypedName ]
             , body :: [Statement]
             }
         | App Exp [ Exp ]
    deriving ( Eq, Ord, Typeable )

-}

