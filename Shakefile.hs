{-# LANGUAGE NamedFieldPuns #-}
import qualified Data.ByteString.Lazy          as BL
import           Data.Csv                                 ( decodeByName )
import           Data.List.Split                          ( splitOn )
import qualified Data.Vector                   as V
import           Development.Shake
import           Development.Shake.Command
import           Development.Shake.FilePath
import           Development.Shake.Util

import           Lib


datafiles :: [FilePath]
datafiles =
  [ "interactive/src/assets/ece.geojson"
  , "interactive/src/rating.json"
  , "interactive/src/types.json"
  , "interactive/src/assets/details.json"
  ]

main :: IO ()
main = do
  allSchools <- getSchools
  let schoolEroPages =
        [ "data" </> "reports" </> "lists" </> schoolNumber <.> "html"
        | School { schoolNumber } <- allSchools
        ]

  shakeArgs shakeOptions { shakeFiles = ".build" } $ do
    want datafiles


    phony "clean" $ do
      putInfo "Cleaning files in .build"
      removeFilesAfter ".build" ["//*"]

    datafiles &%> \_ -> do
      need ["data/ranked-schools.csv", "data.R"]
      cmd_ "Rscript data.R"

    "data/Directory-ECE-Current.clean.csv" %> \_ -> do
      need ["data/Directory-ECE-Current.csv", "data/Directory-ECE-Current.R"]
      cmd_ "Rscript data/Directory-ECE-Current.R"

    phony "download report list" $ do
      putInfo "Find Ero reports"
      need schoolEroPages

    phony "download reports" $ do
      putInfo "Downloading ERO reports"
      need ["data/reports.txt"]
      bs <- liftIO $ BL.readFile "data/reports.txt"
      let (Right (_, reps)) = decodeByName bs
      need
        [ "data" </> "reports" </> sn </> d <.> "html"
        | (ReportLink sn d _) <- V.toList reps
        ]

    "data/ranked-schools.csv" %> \o -> do
      bs <- liftIO $ BL.readFile "data/reports.txt"
      let (Right (_, reps)) = decodeByName bs
      need
        ( "data/reports.txt"
        : [ "data" </> "reports" </> sn </> d <.> "html"
          | (ReportLink sn d _) <- V.toList reps
          ]
        )
      putInfo "grabbing ranks"
      liftIO $ ranks o "data/reports.txt"

    "data/reports.txt" %> \o -> do
      need schoolEroPages
      liftIO $ allReports o schoolEroPages

    priority 2 $ "data/reports/lists/*.html" %> \o -> do
      let sn = takeBaseName o
      putInfo $ "downloading " ++ sn
      liftIO $ reportListPage sn

    priority 1 $ "data/reports/**/*.html" %> \o -> do
      putInfo $ "downloading " ++ o
      liftIO $ report o




