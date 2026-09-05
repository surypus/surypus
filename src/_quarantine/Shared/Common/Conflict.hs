module Shared.Common.Conflict where

import Data.Text (Text)

resolveConflict :: Text -> Text -> Text
resolveConflict server _client = server -- LWW for metadata
