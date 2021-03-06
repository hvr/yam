{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import qualified Data.Text               as T
import           Test.Hspec
import           Test.QuickCheck.Monadic
import           Yam

main = hspec spec

spec :: Spec
spec = do
  describe "Yam.Config" specConfig

specConfig = do
  context "randomTest" $ do
    it "random" $ do
      monadicIO $ do
        s <- run $ randomString 14
        assert (T.length s == 14)
