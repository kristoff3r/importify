{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

-- | This executable generated .golden tests for importify.

module Main where

import           Universum

import           Path              (fromRelFile, parseRelFile, (-<.>))
import           Path.IO           (removeFile)
import           Test.Tasty.Golden (findByExtension, writeBinaryFile)

import           Importify.Main    (importifyFileContent)
import           Importify.Path    (testDataDir)

main :: IO ()
main = do
    arguments <- getArgs
    case arguments of
        ["--clean"] -> cleanGoldenExamples
        ["--force"] -> generateGoldenTestsPrompt True
        []          -> generateGoldenTestsPrompt False
        _           -> putText "Incorrect arguments!"

cleanGoldenExamples :: IO ()
cleanGoldenExamples = do
    goldenExamples <- findByExtension [".golden"] testDataDir
    mapM_ (parseRelFile >=> removeFile) goldenExamples

generateGoldenTestsPrompt :: Bool -> IO ()
generateGoldenTestsPrompt True  = generateGoldenTests
generateGoldenTestsPrompt False = do
    putText "> Are you sure want to generate new golden examples? [y/N]"
    getLine >>= \case
        "y" -> generateGoldenTests
        _   -> putText "Aborting generation"

generateGoldenTests :: IO ()
generateGoldenTests = do
    testCaseFiles <- findByExtension [".hs"] testDataDir
    forM_ testCaseFiles $ \testCaseFile -> do
       testCasePath      <- parseRelFile testCaseFile
       Right modifiedSrc <- importifyFileContent testCasePath
       goldenPath        <- testCasePath -<.> "golden"
       writeBinaryFile (fromRelFile goldenPath) (toString modifiedSrc)
