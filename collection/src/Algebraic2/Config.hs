{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DatatypeContexts #-}
{-# LANGUAGE DeriveDataTypeable #-}

module Algebraic2.Config where

import Autolib.TES.Identifier
import qualified Autolib.TES.Binu as B
import Expression.Op

import Data.Typeable

import Autolib.ToDoc
import Autolib.Reader
import Autolib.Set
import Autolib.FiniteMap

data Information = Formula | Value deriving Typeable

derives [makeToDoc, makeReader] [''Information]

data Ops a => Type c r a =
     Make { context :: c
	  , operators_in_instance :: B.Binu ( Op a )
	 , max_formula_size_for_instance :: Int
	 , restrictions_for_instance :: [ r ]
	 -- | those with @Left@ will be chosen randomly (under restrictions)
	 , predefined :: FiniteMap Identifier ( Either Information a )
	 , max_formula_size_for_predefined :: Int
	 , restrictions_for_predefined :: [ r ]
         , information :: Information
	 , operators_in_solution :: B.Binu ( Op a )
	 , max_formula_size_for_solution :: Int
         , solution_candidates :: Int
         , instance_candidates :: Int
         , small_solution_candidates :: Int   
	 }
     deriving ( Typeable )

derives [makeReader, makeToDoc] [''Type]



