{-# LANGUAGE OverloadedStrings #-}

-- Generate Parsers for a data type.
--
-- Parsers are built from hand-written basic parsers, namely
--  StringParser, ...    (basic types)
--  EitherParser<A, B>   (Either a b)
--  ListParser<A>        ([a])
--  ArrayElemParser<A>   (data ... = ... a ...)
--  StructFieldParser<A> (data ... = ... { ... foo :: a ... } ...)
--  AlternativeParser<A> (data ... = a0 | a1 ...)
--
-- See the corresponding Java code for details.

module JParser (
    dir,
    jParser
) where

import Types
import Java
import Basic
import Package

import Data.String
import System.FilePath
import Control.Monad
import Text.PrettyPrint.HughesPJ

package :: String
package = base ++ ".xmlrpc.parse"

tpackage :: String
tpackage = base ++ ".types"

dir :: FilePath
dir = "out" </> "parse"

clasz :: IsString s => s
clasz = "Parser"

-- file header
header = [
    "package" <+> text package <> ";",
    "import" <+> text (tpackage ++ ".*") <> ";",
    "import" <+> "java.util.List" <> ";",
    "",
    "@SuppressWarnings" <> "(" <> string "unused" <> ")"
 ]

-- generate the parser
jParser :: AData -> IO ()
-- simple case: no type arguments: provide a singleton for the parser.
jParser (AData ty@(AType nm tv) cons) | null tv =
    vWriteFile (dir </> (nm ++ clasz) <.> "java") $ show $ vcat $ header ++ [
        "public" <+> "class" <+> text (nm ++ clasz),
        block [
            "private" <+> "static" <+> "final" <+> clasz
                <> vars [AType nm []] <+> "inst" <+> "=",
            (nest 4 $ foldAlternatives nm tv
                $ map (makeAlternative nm tv) cons) <> ";",
            "",
            "public" <+> "static" <+> clasz
                <> vars [AType nm []] <+> "getInstance" <> "()",
            block [
                "return" <+> "inst" <> ";"
            ]
        ]
    ]
-- hard case
jParser (AData ty@(AType nm tv) cons) =
    vWriteFile (dir </> (nm ++ clasz) <.> "java") $ show $ vcat $ header ++ [
        "public" <+> "class" <+> tipe (AType (nm ++ clasz) tv),
        nest 4 $ "implements" <+> clasz <> vars [ty],
        block $ [
            "private" <+> "final" <+> clasz <> vars [ty] <+>
                 "parser" <> ";",
            "",
            "public" <+> text (nm ++ clasz) <> "(" <> sep (punctuate "," [
                "final" <+> clasz <> vars [ty] <+> ident [nm, clasz]
                | ty@(AVar nm) <- tv
            ]) <> ")",
            block $ [
                "parser" <+> "=" <+>
                    (nest 4 $ foldAlternatives nm tv
                        $ map (makeAlternative nm tv) cons) <> ";"
            ],
            "public" <+> tipe ty <+> "parse" <> "("
                     <> "Object" <+> "val" <> ")"
                     <+> "throws" <+> "ParseErrorBase",
            block [
                "return" <+> "parser" <> "." <> "parse"
                    <> "(" <> "val" <> ")" <> ";"
            ]
         ]
     ]

-- handle alternatives using AlternativeParser
foldAlternatives :: String -> [AType] -> [Doc] -> Doc
foldAlternatives nm tv [x] = x
foldAlternatives nm tv (x:xs) = vcat [
    "new" <+> "AlternativeParser" <> vars [AType nm tv] <> "(",
    nest 4 (x <> "," $$ foldAlternatives nm tv xs),
    ")"
 ]

-- handle a single alternative.
makeAlternative :: String -> [AType] -> ACons -> Doc
makeAlternative nm tv con = let
    cn = consName con
    wrapField = case con of
        ACons {} -> \nm ty i f -> "new" <+> "ArrayElemParser" <>
            vars [ty] <> "(" <> text (show i) <> ","
                $$ nest 4 (f <> ")")
        ARec {} ->  \nm ty i f -> "new" <+> "StructFieldParser" <>
            vars [ty] <> "(" $$ nest 4 (string nm <> ","
                $$ f <> ")")
  in
    -- now provide a parser for each data field of the constructor
    -- note the lazy initialisation - we need that because our parsers
    -- can be recursive, e.g. for  data List = Nil | Cons Int List
    vcat [
        "new" <+> "StructFieldParser" <> vars [AType nm tv]
            <> "(",
        nest 4 $ vcat [
            string cn <> ",",
            "new" <+> clasz <> vars [AType nm tv] <> "()",
            block $ concat [
                [
                    clasz <> vars [ty'] <+> ident [nm', clasz]
                        <+> "=" <+> "null" <> ";"
                ]
                | (nm', ty') <- consArgs con
            ] ++ [
                "",
                "public" <+> tipe (AType nm tv) <+> "parse" <> "("
                     <> "Object" <+> "val" <> ")"
                     <+> "throws" <+> "ParseErrorBase",
                block $ concat [
                    [
                        "if" <+> "(" <> ident [nm', clasz] <+> "=="
                            <+> "null" <> ")",
                        nest 4 $ ident [nm', clasz] <+> "="
                            <+> wrapField nm' ty' i (makeTypeParser ty') <> ";"
                    ]
                    | ((nm', ty'), i) <- zip (consArgs con) [0..]
                ] ++ [
                    "return" <+> "new" <+> tipe (AType cn tv) <> "(",
                    nest 4 $ vcat (punctuate "," [
                        unboxFunc ty (ident [nm, clasz] <> "." <> "parse"
                            <> "(" <> "val" <> ")")
                        | (nm, ty) <- consArgs con
                    ]) <> ")" <> ";"
                ]
            ]
        ],
        ")"
    ]

-- create a new parser given a type
makeTypeParser :: AType -> Doc
makeTypeParser (AType nm tys) | null tys =
    text (upcase $ nm ++ clasz) <> "." <> "getInstance" <> "()"
makeTypeParser (AType nm tys) =
    "new" <+> text (upcase $ nm ++ clasz) <> vars tys
        <> "(" <> sep (punctuate "," (map makeTypeParser tys)) <> ")"
makeTypeParser (AVar nm) =
    ident [nm, clasz]
