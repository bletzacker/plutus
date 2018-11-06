{-# LANGUAGE AutoDeriveTypeable    #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE DerivingStrategies    #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE TypeOperators         #-}

module PSGenerator
  ( generate
  ) where

import           Control.Applicative                ((<|>))
import           Control.Lens                       (set, (&))
import Control.Monad.Reader.Class (MonadReader)
import           Data.Aeson                         (FromJSON, ToJSON)
import           Data.Monoid                        ()
import           Data.Proxy                         (Proxy (Proxy))
import qualified Data.Set                           as Set ()
import           Data.Swagger                       (Schema)
import           Data.Text                          (Text)
import qualified Data.Text                          as T ()
import qualified Data.Text.Encoding                 as T ()
import qualified Data.Text.IO                       as T ()
import           GHC.Generics                       (Generic)
import           Language.PureScript.Bridge         (BridgePart, Language (Haskell), SumType, buildBridge, mkSumType,
                                                     stringBridge, writePSTypes, typeName, (^==), PSType, psTypeParameters, TypeInfo(TypeInfo), BridgeData, typeModule)
import           Language.PureScript.Bridge.PSTypes (psInt)
import           Playground.API                     (API, Evaluation, Fn, FunctionSchema, SourceCode)
import qualified Playground.API                     as API
import           Playground.Interpreter             (CompilationError)
import           Servant.API                        ((:>), Capture, Get, JSON, PlainText, Post, ReqBody)
import           Servant.PureScript                 (HasBridge, Settings, apiModuleName, defaultBridge, defaultSettings,
                                                     languageBridge, writeAPIModuleWithSettings, _generateSubscriberAPI)
import           Wallet.UTXO.Types                  (Blockchain)

myBridge :: BridgePart
myBridge = defaultBridge <|> integerBridge

integerBridge :: BridgePart
integerBridge = do
  typeName ^== "Integer"
  pure psInt

insOrdHashMapBridge :: BridgePart
insOrdHashMapBridge = do
  typeName ^== "InsOrdHashMap"
  psMap

psMap :: MonadReader BridgeData m => m PSType
psMap = TypeInfo "purescript-maps" "Data.Map" "Map" <$> psTypeParameters

aesonBridge :: BridgePart
aesonBridge = do
  typeName ^== "Value"
  typeModule ^== "Data.Aeson.Types.Internal"
  pure psJson

psJson :: PSType
psJson = TypeInfo "purescript-argonaut-core" "Data.Argonaut.Core" "Json" []

data MyBridge

myBridgeProxy :: Proxy MyBridge
myBridgeProxy = Proxy

instance HasBridge MyBridge where
  languageBridge _ = buildBridge myBridge

myTypes :: [SumType 'Haskell]
myTypes =
  [ mkSumType (Proxy @FunctionSchema)
  , mkSumType (Proxy @Fn)
  , mkSumType (Proxy @SourceCode)
  , mkSumType (Proxy @Schema)
  , mkSumType (Proxy @CompilationError)
  ]

mySettings :: Settings
mySettings =
  (defaultSettings & set apiModuleName "Playground.Server")
    {_generateSubscriberAPI = False}

generate :: FilePath -> IO ()
generate outputDir = do
  writeAPIModuleWithSettings
    mySettings
    outputDir
    myBridgeProxy
    (Proxy :: Proxy ("contract" :> ReqBody '[ JSON] SourceCode :> Post '[ JSON] [FunctionSchema]))
  writePSTypes outputDir (buildBridge myBridge) myTypes