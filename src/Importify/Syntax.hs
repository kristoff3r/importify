{-# LANGUAGE LambdaCase   #-}
{-# LANGUAGE ViewPatterns #-}

-- | Common utilities for import list processing

module Importify.Syntax
       ( InScoped
       , getImportModuleName
       , getModuleNameId
       , getModuleTitle
       , getSourceModuleName
       , importSlice
       , parseForImports
       , pullScopedInfo
       , scopedNameInfo
       , unscope

       , debugAST
       ) where

import           Universum

import qualified Data.List.NonEmpty                 as NE
import           Language.Haskell.Exts              (Annotated (ann), CName (..),
                                                     Extension, ImportDecl (..),
                                                     ImportSpec (..), Module (..),
                                                     ModuleName, ModuleName (..),
                                                     Name (..), NonGreedy (..),
                                                     ParseResult (..),
                                                     PragmasAndModuleName (..),
                                                     SrcSpan (..), SrcSpanInfo (..),
                                                     combSpanInfo, fromParseResult, parse,
                                                     parseFileContentsWithExts)
import           Language.Haskell.Names             (NameInfo, Scoped (..))
import           Language.Haskell.Names.SyntaxUtils (getModuleName)
import           Text.Show.Pretty                   (ppShow)

-- | Short wrapper for types annotated by @Scoped SrcSpanInfo@.
-- For example, use @InScoped ImportDecl@ instead of @ImportDecl (Scoped SrcSpanInfo)@.
type InScoped t = t (Scoped SrcSpanInfo)

-- | Returns module name for 'ImportDecl' with annotation erased.
getImportModuleName :: ImportDecl l -> ModuleName ()
getImportModuleName ImportDecl{..} = () <$ importModule

startAndEndLines :: SrcSpanInfo -> (Int, Int)
startAndEndLines (SrcSpanInfo SrcSpan{..} _) = (srcSpanStartLine, srcSpanEndLine)

-- | Returns pair of line numbers — first and last line of import section
-- if any import is in list.
importSlice :: [ImportDecl SrcSpanInfo] -> Maybe (Int, Int)
importSlice []               = Nothing
importSlice [ImportDecl{..}] = Just $ startAndEndLines importAnn
importSlice (x:y:xs)         = Just $ startAndEndLines
                                    $ combSpanInfo (importAnn x) (importAnn $ NE.last (y :| xs))

-- | Returns module name of the source file.
-- We can't parse the whole file to get it because default extensions are not available yet
-- so this method uses 'NonGreedy' parsing to parse only module head.
getSourceModuleName :: Text -> String
getSourceModuleName src =
    let parseResult :: ParseResult (NonGreedy (PragmasAndModuleName SrcSpanInfo))
        parseResult = parse $ toString src
        NonGreedy (PragmasAndModuleName _ _pragmas maybeModuleName) =
            fromParseResult parseResult
        ModuleName _ modNameStr =
            fromMaybe (error "File doesn't have `module' declaration") maybeModuleName
    in modNameStr

parseForImports :: [Extension] -> Text -> (Module SrcSpanInfo, [ImportDecl SrcSpanInfo])
parseForImports exts fileContent = (ast, imports)
    where ast@(Module _ _ _ imports _) =
              fromParseResult $ parseFileContentsWithExts exts $ toString fileContent

-- | Returns name of 'Module' as a 'String'.
getModuleTitle :: Module l -> String
getModuleTitle (getModuleName -> ModuleName _ name) = name

-- | Get name of module by dropping annonation.
getModuleNameId :: ModuleName l -> String
getModuleNameId (ModuleName _ id) = id

-- | Retrive 'NameInfo' from 'Scoped'.
scopedNameInfo :: Scoped l -> NameInfo l
scopedNameInfo (Scoped info _) = info

-- | Retrive 'NameInfo' from something annotated by 'Scoped'.
pullScopedInfo :: Annotated ast => ast (Scoped l) -> NameInfo l
pullScopedInfo = scopedNameInfo . ann

-- | Drop 'Scoped' annotation from 'Functor' type.
unscope :: Functor f => f (Scoped l) -> f l
unscope = fmap $ \case Scoped _ l -> l

-- | Helper function to debug different parts of AST processing.
-- TODO: remove when logging appear.
{-# WARNING debugAST "'debugAST' remains in code" #-}
debugAST :: Show a => Text -> a -> IO ()
debugAST header msg = do
    putText $ "-------------------- // " <> header <> " // --------------------"
    putText $ toText $ ppShow msg