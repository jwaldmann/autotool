module Code.Huffman.Partial where

--  $Id$

import Code.Type
import Code.Check

import Code.Huffman.LR
import Code.Huffman.Test

import Challenger.Partial
import Reporter
import ToDoc


data Huffman = Huffman deriving ( Eq, Ord, Show, Read )

instance ( ToDoc a, ToDoc [a], Ord a ) 
	 => Partial Huffman ( Frequency a ) ( Code a LR ) where

    describe p i = vcat
        [ text "gesucht ist ein optimaler Pr�fix-Code"
	, nest 4 $ vcat [ text "�ber dem Code-Alphabet [L, R]"
			, text "f�r die Verteilung" <+> toDoc i
			]
	]

    initial p i = listToFM $ do
        ( k, x ) <- zip [0..] $ keysFM i
	return ( x, replicate k L ++ [ R ] )

    partial p i b = do
        isprefix b
	istotal ( mkSet $ keysFM i ) b

    total p i b  = do
        isoptimalprefix i b
        