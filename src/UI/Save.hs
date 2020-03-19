-- TODO: rename stuff to *save* and not file browser etc
{-# LANGUAGE OverloadedStrings #-}
module UI.Save where

import Control.Monad.IO.Class
import qualified Data.ByteString as ByteString
import qualified Data.Text as Text
import Control.Exception (displayException)

import qualified Brick.Main as M
import qualified Brick.Widgets.FileBrowser as FB
import qualified Graphics.Vty as V
import qualified Brick.Types as T
import Brick.Widgets.Center (center, hCenter)
import Brick.Widgets.Border (borderWithLabel)
import System.FilePath (takeFileName)
import Brick.Widgets.Core
  ( vLimitPercent
  , hLimitPercent
  , (<=>)
  , txt
  , padTop
  , vBox
  , emptyWidget
  , str
  , withDefAttr
  )

import UI.Util
import GopherClient (downloadGet)
import UI.Style

downloadState :: GopherBrowserState -> String -> Int -> String -> IO GopherBrowserState
downloadState gbs host port resource =  do
  o <- downloadGet host (show port) resource
  --BS.writeFile "usefilechoserhere" o >> pure gbs-- XXX FIXME
  x <- FB.newFileBrowser selectNothing MyViewport Nothing
  pure $ gbs
    { gbsRenderMode = FileBrowserMode
    , gbsBuffer = FileBrowserBuffer { fbFileBrowser = x
                                    -- should be move FIXME
                                    , fbCallBack = (`ByteString.writeFile` o)
                                    , fbIsNamingFile = False
                                    , fbFileOutPath = ""
                                    , fbOriginalFileName = takeFileName resource
                                    , fbFormerBufferState = gbsBuffer gbs
                                    }
    }
  where
    -- | This is for FileBrowser, because we don't want to overwrite anything,
    -- we want to browse through directories and then enter in a file name.
    selectNothing :: FB.FileInfo -> Bool
    selectNothing _ = False

-- FIXME: only need to return GopherBrowserState actually
-- | Overrides handling file browse revents because we have a special text entry mode!
--- See also: handleFileBrowserEvent
handleFileBrowserEvent' :: (Ord n) => GopherBrowserState -> V.Event -> FB.FileBrowser n -> (GopherBrowserState, T.EventM n (FB.FileBrowser n))
handleFileBrowserEvent' gbs e b =
    -- FIXME: okay this is very wrong/messed up. take another look at regular handleFIleBrowserEvent'
    if not isNamingFile && e == V.EvKey (V.KChar 'n') [] then
        (initiateNamingState, pure b)
    else if isNamingFile then
      case e of
        V.EvKey V.KEnter [] -> (finalOutFilePath $ (FB.getWorkingDirectory b) ++ "/" ++ curOutFilePath, pure b)
        V.EvKey V.KBS [] -> (updateOutFilePath $ take (length curOutFilePath - 1) curOutFilePath, pure b)
        V.EvKey (V.KChar c) [] -> (updateOutFilePath $ curOutFilePath ++ [c], pure b)
        _ -> (gbs, FB.handleFileBrowserEvent e b)
    else
      (gbs, FB.handleFileBrowserEvent e b)
    where
      initiateNamingState :: GopherBrowserState
      initiateNamingState = gbs { gbsBuffer = (gbsBuffer gbs) { fbIsNamingFile = True, fbFileOutPath = (fbOriginalFileName (gbsBuffer gbs)) } }

      finalOutFilePath p = gbs { gbsBuffer = (gbsBuffer gbs) { fbFileOutPath = p, fbIsNamingFile = False } }

      isNamingFile = fbIsNamingFile (gbsBuffer gbs)

      updateOutFilePath p = gbs { gbsBuffer = (gbsBuffer gbs) { fbFileOutPath = p } }

      curOutFilePath = fbFileOutPath (gbsBuffer gbs)

-- FIXME
fileBrowserUi :: GopherBrowserState -> [T.Widget MyName]
fileBrowserUi gbs = [center $ vLimitPercent 100 $ hLimitPercent 100 $ ui <=> help]
    where
        b = fromBuffer $ gbsBuffer gbs
        fromBuffer x = fbFileBrowser x
        ui = hCenter $
             borderWithLabel (txt "Choose a file") $
             FB.renderFileBrowser True b
        help = padTop (T.Pad 1) $
               vBox [ case FB.fileBrowserException b of
                          Nothing -> emptyWidget
                          Just e -> hCenter $ withDefAttr errorAttr $
                                    txt $ Text.pack $ displayException e
                    , hCenter $ txt "Up/Down: select"
                    , hCenter $ txt "/: search, Ctrl-C or Esc: cancel search"
                    , hCenter $ txt "Enter: change directory or select file"
                    , hCenter $ txt "Esc: quit"
                    , hCenter $ str $ fbFileOutPath (gbsBuffer gbs)
                    ]

saveEventHandler :: GopherBrowserState -> V.Event -> T.EventM MyName (T.Next GopherBrowserState)
saveEventHandler gbs e =
  case e of
    -- instances of 'b' need to tap into gbsbuffer
    V.EvKey V.KEsc [] | not (FB.fileBrowserIsSearching $ fromFileBrowserBuffer (gbsBuffer gbs)) ->
      M.continue $ returnFormerState gbs
    _ -> do
      let (gbs', bUnOpen') = handleFileBrowserEvent' gbs e (fromFileBrowserBuffer $ gbsBuffer gbs)
      b' <- bUnOpen'
      -- If the browser has a selected file after handling the
      -- event (because the user pressed Enter), shut down.
      let fileOutPath = fbFileOutPath (gbsBuffer gbs')
      if (isNamingFile gbs') then
        M.continue (updateFileBrowserBuffer gbs' b')
      -- this errors now
      else if not (null $ getOutFilePath gbs') then
        (liftIO (doCallBack fileOutPath) >>= M.continue)
      else
        M.continue (updateFileBrowserBuffer gbs' b')
  where
    fromFileBrowserBuffer x = fbFileBrowser x
    returnFormerState g = g {gbsBuffer = (fbFormerBufferState $ gbsBuffer g), gbsRenderMode = MenuMode}
    isNamingFile g = fbIsNamingFile (gbsBuffer g)
    updateFileBrowserBuffer g bu = g { gbsBuffer = (gbsBuffer g) { fbFileBrowser = bu }  }
    getOutFilePath g = fbFileOutPath (gbsBuffer g)
    doCallBack a = do
      fbCallBack (gbsBuffer gbs) a
      pure $ gbs {gbsBuffer = (fbFormerBufferState $ gbsBuffer gbs), gbsRenderMode = MenuMode}
