{-# language DeriveDataTypeable #-}
{-# language DoAndIfThenElse #-}

module Rewriting.Termination.Matrix where

import Rewriting.Termination.Semiring

import Autolib.Reader
import Autolib.ToDoc

import Control.Monad ( when )
import Control.Applicative ( (<$>) )
import Data.Typeable
import Data.List ( transpose )

data Matrix d = Matrix { dim :: (Int,Int) , contents :: [[d]] }
    deriving ( Eq, Typeable )

instance Semiring d => Semiring (Matrix d) where
    strict_addition = strict_addition . top_left 
    plus = mplus ; times = mtimes
    -- zero and one cannot be implemented 
    -- since they need dimension info
    positive = positive . top_left
    is_zero = all (all is_zero ) . contents 
    strictly_greater a b = case strict_addition a of
        True -> strictly_greater (top_left a) (top_left b)
            && weakly_greater a b 
        False -> all and 
            $ zipWith (zipWith ( \ x y -> (is_zero x && is_zero y) || strictly_greater x y)) (contents a) (contents b)
    weakly_greater a b = all and
            $ zipWith (zipWith weakly_greater) (contents a) (contents b)

top_left m = contents m !! 0 !! 0

is_zero_matrix m = all (all is_zero) $ contents m

mplus a b | dim a == dim b = 
    Matrix { dim = dim a 
           , contents = zipWith (zipWith plus) 
                 (contents a) (contents b)
           }

mtimes a b | snd (dim a) == fst (dim b) =
    Matrix { dim = ( fst $ dim a, snd $ dim b )
           , contents = for (contents a) $ \ row -> 
                        for (transpose $ contents b) $ \ col ->
                        foldr plus zero $ zipWith times row col
           }

zero_matrix (h,w) = 
    Matrix { contents = replicate h $ replicate w $ zero
           , dim = (h,w)
           }

unit_matrix d = 
    Matrix { contents = for [1..d] $ \ x -> 
                        for [1..d] $ \ y -> 
                        if x==y then one else zero
           , dim = (d,d)
           }

for = flip map

instance (Semiring d, ToDoc d) => ToDoc (Matrix d) where
    toDoc m 
        | is_zero_matrix m = text "zero" <+> toDoc (dim m)
        | Just d <- is_unit_matrix m = text "unit" <+> toDoc d
        | otherwise = case dim m of
            (1,1) -> text "scalar" <+> toDoc (contents m !! 0 !! 0)
            (1,d) -> text "row" <+> toDoc (contents m !! 0)
            (d,1) -> text "column" <+> toDoc (map (!! 0) $ contents m)
            _ -> text "matrix" <+> toDoc (contents m)

is_unit_matrix :: (Semiring d) => Matrix d -> Maybe Int
is_unit_matrix m = do
    let (r,c) = dim m
    guard $ r == c
    guard $ m == unit_matrix r
    return r

instance (Semiring d, Reader d) => Reader (Matrix d) where
    reader = 
            do my_reserved "zero" ; zero_matrix <$> reader
        <|> do my_reserved "unit" ; unit_matrix <$> reader
        <|> do my_reserved "scalar" ; x <- reader 
               return $ Matrix { contents = [[x]] , dim = (1,1) }
        <|> do my_reserved "column" ; xs <- reader
               return $ Matrix 
                   { contents = map return xs
                   , dim = (length xs, 1)
                   }
        <|> do my_reserved "row" ; xs <- reader
               return $ Matrix 
                   { contents = return xs
                   , dim = (1, length xs)
                   }
        <|> do my_reserved "matrix" 
               xss <- reader
               if null xss then fail "matrix height cannot be zero"
               else do let ls = map length xss
                           (lo,hi) = (minimum ls, maximum ls)
                       if (lo /= hi) 
                       then fail "matrix rows differ in length"
                       else return $ Matrix { contents = xss 
                                            , dim = (length ls, lo)
                                            }
