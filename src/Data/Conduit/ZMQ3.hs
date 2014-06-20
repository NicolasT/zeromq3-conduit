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

{-# LANGUAGE Rank2Types #-}

-- | This module implements interfaces between "Data.Conduit" and
-- "System.ZMQ3", so ZeroMQ 'ZMQ.Socket's can be used as 
-- 'Source's and 'Sink's in Conduit-based applications.

module Data.Conduit.ZMQ3 (
    -- * Conduit Sources from ZMQ Sockets
      zmqSource
    , zmqSourceMulti

    -- * Conduit Sinks from ZMQ Sockets
    , zmqSink
    , zmqSinkLazy
    , zmqSinkMulti
    ) where

import Control.Monad.Trans (lift)
import Control.Monad.IO.Class (MonadIO)

import Data.List.NonEmpty (NonEmpty)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS

import Data.Conduit

import qualified System.ZMQ3 as ZMQ (Receiver, Sender, Socket)
import qualified System.ZMQ3.Monad as ZMQ

-- Sources
zmqSourceGeneric :: Monad m => (s -> m a) -> s -> Source m a
zmqSourceGeneric f s = loop
  where
    loop = lift (f s) >>= yield >> loop
    {-# INLINE loop #-}
{-# INLINE zmqSourceGeneric #-}

-- | Turn a 'ZMQ.Socket' into a 'Source', using 'ZMQ.receive'
zmqSource :: (MonadIO m, ZMQ.Receiver s) => ZMQ.Socket s -> Source m BS.ByteString
zmqSource = zmqSourceGeneric ZMQ.receive
-- | Turn a 'ZMQ.Socket' into a 'Source', using 'ZMQ.receiveMulti'
zmqSourceMulti :: (MonadIO m, ZMQ.Receiver s) => ZMQ.Socket s -> Source m [BS.ByteString]
zmqSourceMulti = zmqSourceGeneric ZMQ.receiveMulti


-- Sinks
zmqSinkGeneric :: Monad m => (a -> m ()) -> Sink a m ()
zmqSinkGeneric f = loop
  where
    loop = await >>= maybe (return ()) (\v -> lift (f v) >> loop)
    {-# INLINE loop #-}
{-# INLINE zmqSinkGeneric #-}

-- | Turn a 'ZMQ.Socket' into a 'Sink', using 'ZMQ.send'
zmqSink :: (MonadIO m, ZMQ.Sender s) => ZMQ.Socket s
                                     -> [ZMQ.Flag]
                                     -> Sink BS.ByteString m ()
zmqSink sock flags = zmqSinkGeneric $ ZMQ.send sock flags
-- | Turn a 'ZMQ.Socket' into a 'Sink', using 'ZMQ.send''
zmqSinkLazy :: (MonadIO m, ZMQ.Sender s) => ZMQ.Socket s
                                         -> [ZMQ.Flag]
                                         -> Sink LBS.ByteString m ()
zmqSinkLazy sock flags = zmqSinkGeneric $ ZMQ.send' sock flags
-- | Turn a 'ZMQ.Socket' into a 'Sink', using 'ZMQ.sendMulti'
zmqSinkMulti :: (MonadIO m, ZMQ.Sender s) => ZMQ.Socket s
                                          -> Sink (NonEmpty BS.ByteString) m ()
zmqSinkMulti = zmqSinkGeneric . ZMQ.sendMulti
