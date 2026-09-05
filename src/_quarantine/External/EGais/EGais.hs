module External.EGais.EGais
  ( EGaisRecord   (..),
    fetchEGaisData
  ) where

import Data.Text (Text)
import Data.Time (UTCTime, getCurrentTime)

data EGaisRecord = EGaisRecord
  { erId :: Int,
    erData :: Text
  }
  deriving (Show, Eq)

fetchEGaisData :: IO [EGaisRecord]
fetchEGaisData = pure []
