{-# language DeriveDataTypeable #-}
{-# language TemplateHaskell #-}
{-# language DatatypeContexts #-}
{-# language MultiParamTypeClasses #-}
{-# language FlexibleInstances #-}
{-# language EmptyCase #-}

module Rewriting.Abstract.Semantics where

import Rewriting.Abstract.Syntax 
import Rewriting.Abstract.Braced

import Autolib.FiniteMap
import qualified Data.Map as M
import qualified Data.Set as S

import Autolib.TES.Identifier
import Autolib.Reporter
import Autolib.ToDoc hiding ( Full) 

import qualified Autolib.Relation as R
import qualified Autolib.Relation.Prop as R

import Control.Applicative

import Prelude hiding ( exp )

type Env dom = M.Map Identifier ( R.Type dom dom )


nodeN name f args = 
    let v = f $ map fst args
    in  ( v, hsep [ text "label:", text name <> comma
                  , text "value:", oneLine $ toDoc v ] 
             </> vcat (map snd args)
        )

oneLine = text . unwords . words . render

node0 name f = nodeN name ( \ [] -> f ) []
node1 name f x = nodeN name ( \ [x] -> f x ) [ x ]
node2 name f x y = nodeN name ( \ [x,y] -> f x y ) [x,y]

node0R name f = 
   let (Braced v, d) = nodeN name ( \ [] -> Braced $ f ) []
   in  (v, d)
node1R name f x = 
   let (Braced v, d) = nodeN name ( \ [x] -> Braced $ f x ) [ x ]
   in  (v, d)
node2R name f x y = 
   let (Braced v, d) = nodeN name ( \ [x,y] -> Braced $ f x y ) [x,y]
   in  (v, d)

prop :: (Ord dom , ToDoc dom)
     => Env dom -> Prop -> Reporter (Bool, Doc)
prop env p = case p of
    PropParens p -> prop env p
    And [b] -> prop env b
    And bs -> nodeN "And" and <$> forM bs ( prop env )
    Or  [b] -> prop env b
    Or  bs -> nodeN "Or"  or  <$> forM bs ( prop env )
    Not b  -> node1 "Not" not <$> prop env b    
    Prop1 p1 x -> 
        node1 (show p1) (prop1 p1) <$> exp env x
    Prop2 p2 x y -> 
        node2 (show p2) (prop2 p2) <$> exp env x <*> exp env y


prop1 p1 r = case p1 of
            Null -> R.null r
            Full -> R.full r
            Reflexive -> R.reflexive r
            Irreflexive -> R.irreflexive r
            Transitive -> R.transitive r
            Symmetric -> R.symmetric r
            Asymmetric -> R.asymmetric r 
            Antisymmetric -> R.antisymmetric r 
            Total -> R.total r
            SN -> 
                 R.null $ R.intersection 
                   (R.flat $ R.source r) (R.trans r)
            WN -> 
                 R.source r == R.effective_source (bang r)
            CR -> 
                let t = R.reflex_trans r ; t' = R.inverse t
                in  R.isSubsetOf ( R.times t' t )
                                  ( R.times t t' )
            WCR ->
                let t = R.reflex_trans r ; t' = R.inverse t
                in  R.isSubsetOf ( R.times (R.inverse r) r )
                                  ( R.times t t' )
            UN -> let b = bang r
                  in  R.diagonal $ R.times (R.inverse b) b
            UNC -> R.diagonal 
               $ R.filter (normal r) (normal r)
               $ R.reflex_trans 
               $ R.plus r ( R.inverse r )


prop2 p2 r s = case p2 of
              Equals -> r == s
              Subsetof -> R.isSubsetOf r s
              Disjoint -> R.null $ R.intersection r s

-- | R^! is R^* with rhs restricted to nfs
bang r = R.rightfilter ( normal r ) $ R.reflex_trans r

normal r y = S.null $ R.images r y 

----------------------------------------------------------

exp :: (Ord dom , ToDoc dom)
    => Env dom -> Exp -> Reporter (R.Type dom dom, Doc)
exp env x = case x of
    ExpParens x -> exp env x
    Ref i -> node0R (show i) <$> case M.lookup i env of
        Nothing -> reject $ text "identifier" <+> toDoc i <+> text "not bound"
        Just v -> return v
    Op1 o x -> node1R (show o) (op1 o) <$> exp env x
    Op2 o x y -> node2R (show o) (op2 o) <$> exp env x <*> exp env y

op1 o = case o of
            Inverse -> R.inverse 
            Complement -> R.complement 
            Transitive_Closure -> R.trans 
            Transitive_Reflexive_Closure -> R.reflex_trans 

op2 o = case o of
            Union -> R.plus 
            Intersection -> R.intersection 
            Difference -> R.difference 
            Product -> R.times 

