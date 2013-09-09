{- zeromq3-conduit - Conduit bindings for zeromq3-haskell
 -
 - Copyright (C) 2012  Nicolas Trangez
 -
 - This library is free software; you can redistribute it and/or
 - modify it under the terms of the GNU Lesser General Public
 - License as published by the Free Software Foundation; either
 - version 2.1 of the License, or (at your option) any later version.
 -
 - This library is distributed in the hope that it will be useful,
 - but WITHOUT ANY WARRANTY; without even the implied warranty of
 - MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 - Lesser General Public License for more details.
 -
 - You should have received a copy of the GNU Lesser General Public
 - License along with this library; if not, write to the Free Software
 - Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 -}

{-# LANGUAGE CPP, FlexibleContexts, GeneralizedNewtypeDeriving #-}

-- | A monad to ease working with "System.ZMQ3", hiding the 'Context'
-- object in a 'ReaderT' environment.
--
-- Example usage:
--
-- > demo :: String -> IO ()
-- > demo addr = runResourceT $ runZMQ 1 $ do
-- >     s <- makeSocket ZMQ.Sub
-- >     bind s
-- >     forever $ do
-- >         msg <- receive s
-- >         liftIO $ print msg

module System.ZMQ3.Monad (
    -- * Monad type and evaluation
      ZMQ
    , runZMQ
    , getContext

    -- * Socket creation
    , makeSocket

    -- * Lifted versions of some System.ZMQ3 actions
    -- ** Socket handling
    , bind
    , connect
    -- ** Send
    , send
    , send'
    , sendMulti
    -- ** Receive
    , receive
    , receiveMulti
    -- ** PubSub
    , subscribe
    , unsubscribe

    -- * Re-exports from System.ZMQ3
    , Size
    , Flag(..)
    , Push(..), Pull(..), Router(..), Dealer(..), Rep(..), Req(..), XSub(..), XPub(..), Sub(..), Pub(..), Pair(..)
    ) where

import Control.Applicative

import Control.Exception.Lifted (bracket)

import Control.Monad.IO.Class (MonadIO, liftIO)

import Control.Monad.Reader (ReaderT, runReaderT)
import Control.Monad.Reader.Class (MonadReader, ask)

import Control.Monad.Trans (MonadTrans)
import Control.Monad.Trans.Control (MonadBaseControl)
import Control.Monad.Trans.Resource (MonadThrow, MonadResource, allocate)

import Data.List.NonEmpty (NonEmpty)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS

import System.ZMQ3
    (Size, Flag, Push, Pull, Router, Dealer, Rep, Req, XSub, XPub, Sub, Pub, Pair)
import qualified System.ZMQ3 as ZMQ

#ifdef DEMO
import Control.Monad.Trans.Resource (runResourceT)
import Control.Monad (forever)
#endif

-- | 'ZMQ' is a 'ReaderT' exposing a 'Context' in its environment
newtype ZMQ m a = ZMQ { unZMQ :: ReaderT ZMQ.Context m a }
  deriving (Functor, Applicative, Monad, MonadIO, MonadReader ZMQ.Context, MonadThrow, MonadTrans, MonadResource)

-- | Run a 'ZMQ' action
--
-- This action will create a 'ZMQ.Context' and execute the given action while
-- providing this context.
-- The context will be terminated once the action has finished.
runZMQ :: (MonadIO m, MonadBaseControl IO m) => Size -- ^ 'ioThreads' argument passed to 'ZMQ.init'
                                             -> ZMQ m a -- ^ Action to execute
                                             -> m a
runZMQ ioThreads act =
    bracket
        (liftIO $ ZMQ.init ioThreads)
        (liftIO . ZMQ.term)
        (runReaderT $ unZMQ act)

-- | Retrieve the context provided in the current environment
getContext :: Monad m => ZMQ m ZMQ.Context
getContext = ask
{-# INLINE getContext #-}

-- | Make a new socket using the local 'ZMQ.Context'. See 'ZMQ.socket' and
-- 'ZMQ.withSocket' for more details.
makeSocket :: (MonadResource m, ZMQ.SocketType s) => s -- ^ Socket type
                                                  -> ZMQ m (ZMQ.Socket s)
makeSocket stype = do
    ctx <- getContext
    snd <$> allocate
                (liftIO $ ZMQ.socket ctx stype)
                (liftIO . ZMQ.close)

-- | Lifted version of 'ZMQ.bind'
bind :: MonadIO m => ZMQ.Socket s -> String -> m ()
bind sock addr = liftIO $ ZMQ.bind sock addr
{-# INLINE bind #-}
-- | Lifted version of 'ZMQ.connect'
connect :: MonadIO m => ZMQ.Socket s -> String -> m ()
connect sock addr = liftIO $ ZMQ.connect sock addr
{-# INLINE connect #-}

-- | Lifted version of 'ZMQ.send'
send :: (MonadIO m, ZMQ.Sender s) => ZMQ.Socket s -> [Flag] -> BS.ByteString -> m ()
send sock flags dat = liftIO $ ZMQ.send sock flags dat
{-# INLINE send #-}
-- | Lifted version of 'ZMQ.send''
send' :: (MonadIO m, ZMQ.Sender s) => ZMQ.Socket s -> [Flag] -> LBS.ByteString -> m ()
send' sock flags dat = liftIO $ ZMQ.send' sock flags dat
{-# INLINE send' #-}
-- | Lifted version of 'ZMQ.sendMulti'
sendMulti :: (MonadIO m, ZMQ.Sender s) => ZMQ.Socket s -> NonEmpty BS.ByteString -> m ()
sendMulti sock dat = liftIO $ ZMQ.sendMulti sock dat
{-# INLINE sendMulti #-}

-- | Lifted version of 'ZMQ.receive'
receive :: (MonadIO m, ZMQ.Receiver s) => ZMQ.Socket s -> m BS.ByteString
receive = liftIO . ZMQ.receive
{-# INLINE receive #-}
-- | Lifted version of 'ZMQ.receiveMulti'
receiveMulti :: (MonadIO m, ZMQ.Receiver s) => ZMQ.Socket s -> m [BS.ByteString]
receiveMulti = liftIO . ZMQ.receiveMulti
{-# INLINE receiveMulti #-}

-- | Lifted version of 'ZMQ.subscribe'
subscribe :: (MonadIO m, ZMQ.Subscriber s) => ZMQ.Socket s -> BS.ByteString -> m ()
subscribe sock name = liftIO $ ZMQ.subscribe sock name
{-# INLINE subscribe #-}
-- | Lifted version of 'ZMQ.unsubscribe'
unsubscribe :: (MonadIO m, ZMQ.Subscriber s) => ZMQ.Socket s -> BS.ByteString -> m ()
unsubscribe sock name = liftIO $ ZMQ.unsubscribe sock name
{-# INLINE unsubscribe #-}

#ifdef DEMO
demo :: String -> IO ()
demo addr = runResourceT $ runZMQ 1 $ do
     s <- makeSocket ZMQ.Sub
     bind s addr
     forever $ do
         msg <- receive s
         liftIO $ print msg
#endif
