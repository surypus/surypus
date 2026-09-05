{-# LANGUAGE OverloadedStrings #-}

{- | PDF text extraction utilities
Phase 22-05 of v3.0 roadmap
-}
module Surypus.PDF (
    extractTextFromPDF,
    PDFParseResult (..),
) where

import Data.Text (Text)
import qualified Data.Text as T

-- | Result of PDF text extraction
data PDFParseResult = PDFParseResult
    { pdfText :: Text
    , pdfPageCount :: Int
    , pdfError :: Maybe Text
    }
    deriving (Show, Eq)

{- | Extract text from PDF content (stub implementation)
In production, would use an external service or library like pdf2text
-}
extractTextFromPDF :: Text -> IO PDFParseResult
extractTextFromPDF content = do
    -- Stub: return the content as-is (would normally extract text from PDF bytes)
    let pageCount = T.count "\f" content + 1 -- Form feed = page separator
    pure $
        PDFParseResult
            { pdfText = content
            , pdfPageCount = pageCount
            , pdfError = Nothing
            }

-- | Extract text from PDF file path (for file-based processing)
extractTextFromPDFPath :: FilePath -> IO PDFParseResult
extractTextFromPDFPath _ = do
    -- Stub: would integrate with pdf2text or similar
    pure $
        PDFParseResult
            { pdfText = ""
            , pdfPageCount = 0
            , pdfError = Just "PDF extraction not yet implemented - use external service"
            }
