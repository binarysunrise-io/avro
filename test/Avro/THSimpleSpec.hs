{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell     #-}
module Avro.THSimpleSpec
where

import           Control.Lens
import           Control.Monad

import qualified Data.Aeson         as J
import           Data.Aeson.Lens
import qualified Data.ByteString    as B
import qualified Data.Char          as Char
import           Data.Monoid        ((<>))
import           Data.Text          (Text)
import qualified Data.Text          as T

import           Test.Hspec

import           Data.Avro
import           Data.Avro.Deriving
import           Data.Avro.Schema

{-# ANN module ("HLint: ignore Redundant do"        :: String) #-}

deriveAvro "test/data/small.avsc"

spec :: Spec
spec = describe "Avro.THSpec: Small Schema" $ do
  let msgs =
        [ Endpoint
          { endpointIps         = ["192.168.1.1", "127.0.0.1"]
          , endpointPorts       = [PortRange 1 10, PortRange 11 20]
          , endpointOpaque      = Opaque "16-b-long-string"
          , endpointCorrelation = Opaque "opaq-correlation"
          , endpointTag         = Left 14
          }
        , Endpoint
          { endpointIps         = []
          , endpointPorts       = [PortRange 1 10, PortRange 11 20]
          , endpointOpaque      = Opaque "opaque-long-text"
          , endpointCorrelation = Opaque "correlation-data"
          , endpointTag         = Right "first-tag"
          }
        ]

  it "should do roundtrip" $
    forM_ msgs $ \msg ->
      fromAvro (toAvro msg) `shouldBe` pure msg

  it "should do full round trip" $
    forM_ msgs $ \msg -> do
      let encoded = encode msg
      let decoded = decode encoded

      decoded `shouldBe` pure msg

  it "should convert to JSON" $ do
    forM_ msgs $ \msg -> do
      let json = J.encode (toAvro msg)
      json ^? key "opaque" . _String      `shouldBe` Just (encodeOpaque $ endpointOpaque msg)
      json ^? key "correlation" . _String `shouldBe` Just (encodeOpaque $ endpointCorrelation msg)

      json ^? key "tag" . _Value . key "int" . _Integral   `shouldBe` endpointTag msg ^? _Left
      json ^? key "tag" . _Value . key "string" . _String  `shouldBe` endpointTag msg ^? _Right
    where
      encodeOpaque :: Opaque -> Text
      encodeOpaque (Opaque bs) = T.pack $ Char.chr . fromIntegral <$> B.unpack bs

