-- |
-- Module      : Data.Git.Ref
-- License     : BSD-style
-- Maintainer  : Vincent Hanquez <vincent@snarc.org>
-- Stability   : experimental
-- Portability : unix
--
{-# LANGUAGE DeriveDataTypeable #-}
module Data.Git.Ref
    ( Ref
    -- * Exceptions
    , RefInvalid(..)
    , RefNotFound(..)
    -- * convert from bytestring and string
    , isHex
    , isHexString
    , fromHex
    , fromHexString
    , fromBinary
    , fromDigest
    , toBinary
    , toHex
    , toHexString
    -- * Misc function related to ref
    , refPrefix
    , cmpPrefix
    , toFilePathParts
    -- * Hash ByteString types to a ref
    , hash
    , hashLBS
    ) where

import qualified Crypto.Hash
import           Crypto.Hash (Digest, SHA1, digestFromByteString)
import           Data.ByteString (ByteString)
import qualified Data.ByteString.Unsafe as B (unsafeIndex)
import qualified Data.ByteString.Lazy as L
import qualified Data.ByteString.Char8 as BC
import           Data.ByteArray.Encoding
import qualified Data.ByteArray as B (convert)

import Data.Char (isHexDigit)
import Data.Data

import Control.Exception (Exception, throw)

-- | represent a git reference (SHA1)
newtype Ref = Ref (Digest SHA1)
    deriving (Eq,Ord,Typeable)

instance Show Ref where
    show = BC.unpack . toHex

-- | Invalid Reference exception raised when
-- using something that is not a ref as a ref.
data RefInvalid = RefInvalid ByteString
    deriving (Show,Eq,Data,Typeable)

-- | Reference wasn't found
data RefNotFound = RefNotFound Ref
    deriving (Show,Eq,Typeable)

instance Exception RefInvalid
instance Exception RefNotFound

isHex :: ByteString -> Bool
isHex = and . map isHexDigit . BC.unpack

isHexString :: String -> Bool
isHexString = and . map isHexDigit

-- | take a hexadecimal bytestring that represent a reference
-- and turn into a ref
fromHex :: ByteString -> Ref
fromHex s =
    case either (const Nothing) Just (convertFromBase Base16 s :: Either String ByteString) >>= digestFromByteString of
        Nothing  -> throw $ RefInvalid s
        Just hsh -> Ref hsh

-- | take a hexadecimal string that represent a reference
-- and turn into a ref
fromHexString :: String -> Ref
fromHexString = fromHex . BC.pack

-- | transform a ref into an hexadecimal bytestring
toHex :: Ref -> ByteString
toHex (Ref bs) = convertToBase Base16 bs

-- | transform a ref into an hexadecimal string
toHexString :: Ref -> String
toHexString (Ref d) = show d

-- | transform a bytestring that represent a binary bytestring
-- and returns a ref.
fromBinary :: ByteString -> Ref
fromBinary b = maybe (throw $ RefInvalid b) Ref $ digestFromByteString b

-- | transform a bytestring that represent a binary bytestring
-- and returns a ref.
fromDigest :: Digest SHA1 -> Ref
fromDigest = Ref

-- | turn a reference into a binary bytestring
toBinary :: Ref -> ByteString
toBinary (Ref b) = B.convert b

-- | returns the prefix (leading byte) of this reference
refPrefix :: Ref -> Int
refPrefix (Ref b) = fromIntegral $ B.unsafeIndex (B.convert b) 0

-- | compare prefix
cmpPrefix :: String -> Ref -> Ordering
cmpPrefix pre ref = pre `compare` (take (length pre) $ toHexString ref)

-- | returns the splitted format "prefix/suffix" for addressing the loose object database
toFilePathParts :: Ref -> (String, String)
toFilePathParts ref = splitAt 2 $ show ref

-- | hash a bytestring into a reference
hash :: ByteString -> Ref
hash = Ref . Crypto.Hash.hash

-- | hash a lazy bytestring into a reference
hashLBS :: L.ByteString -> Ref
hashLBS = Ref . Crypto.Hash.hashlazy
