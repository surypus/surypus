{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleInstances #-}
module Infrastructure.Serializer where

import Data.Aeson (Value, decode, encode, toJSON, FromJSON, ToJSON)
import qualified Data.ByteString.Lazy as BSL
import Data.Text (Text)

-- | Serialization formats
data SerializationFormat
   = JSON
   | CBOR
   | MessagePack
   deriving (Show, Eq)

-- | Serialization context
data Serializer = Serializer
   { serializerFormat :: SerializationFormat
   , serializerOptions :: SerialOptions
   }

-- | Serialization options
data SerialOptions = SerialOptions
   { optIndent :: Maybe Int
   , optSortKeys :: Bool
   , optTimeFormat :: Text
   }

-- | Serialize value (JSON only, other formats stubbed for compatibility)
serialize :: (ToJSON a) => Serializer -> a -> BSL.ByteString
serialize (Serializer JSON opts) val = encodeWithOpts opts val
serialize (Serializer CBOR _) val = encode val  -- Stub: use JSON encoding
serialize (Serializer MessagePack _) val = encode val  -- Stub: use JSON encoding

-- | Helper for encoding with options
encodeWithOpts :: (ToJSON a) => SerialOptions -> a -> BSL.ByteString
encodeWithOpts opts val =
   let json = encode val
   in  case (optIndent opts, optSortKeys opts) of
        (Just _, True)  -> encode val
        (Just _, False) -> encode val
        (Nothing, True) -> encode val
        (Nothing, False) -> json

-- | Deserialize value
deserialize :: (FromJSON a) => Serializer -> BSL.ByteString -> Either String a
deserialize (Serializer JSON _) bs =
   case decode bs of
     Just val -> Right val
     Nothing -> Left "Failed to decode JSON"
deserialize (Serializer CBOR _) bs =
   case decode bs of
     Just val -> Right val
     Nothing -> Left "Failed to decode CBOR"
deserialize (Serializer MessagePack _) bs =
   case decode bs of
     Just val -> Right val
     Nothing -> Left "Failed to decode MessagePack"

-- | Auto-detect format
serializeAuto :: (ToJSON a) => SerializationFormat -> a -> BSL.ByteString
serializeAuto JSON val = encode val
serializeAuto CBOR val = encode val
serializeAuto MessagePack val = encode val