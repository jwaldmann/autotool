module PL.ToDoc where

import PL.Data

import Autolib.ToDoc


import Autolib.TES.Identifier

instance ToDoc Formel where
    toDocPrec p ( Operation op xs ) = case xs of
        [x]   -> toDoc op <+> toDocPrec 9 x
	[x,y] -> let q = case op of  
		       And -> 8 ; Or -> 6 ; Iff -> 4 ; Implies -> 2
		 in  docParen ( p > q )
		     $ sep [ toDocPrec (q+1) x , toDoc op <+> toDocPrec q y ]
    toDocPrec p ( Quantified q x f )= docParen ( p > 9 ) $
        toDoc q <+> toDoc x <+> toDocPrec 9 f
    toDocPrec p ( Predicate r xs ) = 
        toDoc r <+> parens ( sepBy comma $ map toDoc xs  )
    toDocPrec p ( Equals l r ) = docParen ( p > 8 )
	$ sep [ toDoc l , text "==", toDoc r ]

instance Show Formel where show = render . toDoc


instance ToDoc Operator where
    toDoc op = case op of
        Not -> text "not"
	And -> text "&&"
	Or -> text "||"
	Iff -> text "<=>"
	Implies -> text "=>"

instance Show Operator where show = render . toDoc

instance ToDoc Quantor where
    toDoc q = case q of
        Forall -> text "forall"
	Exists -> text "exists"
	Count comp n -> text "count" <+> toDoc comp <+> toDoc n

instance ToDoc Compare where
    toDoc c = text $ case c of
        Less -> "<"
	Less_Equal -> "<="
	Equal -> "=="
	Not_Equal -> "!="
	Greater_Equal -> ">="
	Greater -> ">"

instance Show Compare where show = render . toDoc

instance ToDoc Term where
    toDoc ( Variable v ) = toDoc v
    toDoc ( Apply f xs ) = 
        toDoc f <+> parens ( sepBy comma $ map toDoc xs )

instance Show Term where show = render . toDoc


