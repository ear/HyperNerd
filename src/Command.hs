{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE TypeSynonymInstances #-}
module Command where

import           Data.Char
import qualified Data.Map as M
import           Data.Maybe
import qualified Data.Text as T
import           Effect
import           Events

type CommandHandler a = Message a -> Effect ()
type CommandTable = M.Map T.Text (T.Text, CommandHandler T.Text)

contramapCH :: (a -> b)
             -> CommandHandler b
             -> CommandHandler a
contramapCH f commandHandler =
    commandHandler . fmap f

data Command a = Command { commandName :: T.Text
                         , commandArgs :: a
                         } deriving (Eq, Show)

renameCommand :: Command a -> T.Text -> Command a
renameCommand command name =
    command { commandName = name }

textAsCommand :: T.Text -> Maybe (Command T.Text)
textAsCommand (T.uncons -> Just ('!', restText)) =
    Just Command { commandName = T.takeWhile isAlphaNum restText
                 , commandArgs = T.dropWhile isSpace $ T.dropWhile isAlphaNum restText
                 }
textAsCommand _ = Nothing

textAsPipe :: T.Text -> [Command T.Text]
textAsPipe t = maybeToList $ textAsCommand t
