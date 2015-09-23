{-# LANGUAGE TemplateHaskell, QuasiQuotes #-}

module Parse where

import Types
import Control.Lens
import Text.ParserCombinators.Parsec
import Data.Maybe (fromMaybe)
import qualified Data.Either
import Language.Haskell.TH.Quote
import Language.Haskell.TH 
import qualified Tables

str2pc :: [(String,PitchClass)]
str2pc = [
    ("a",A)
   ,("b",B)
   ,("c",C)
   ,("bf",As)
    ]

pitchClass :: GenParser Char st (PitchClass,Accidental)
pitchClass = do
    str <- many lower
    case (lookup str Tables.en) of
        Nothing -> fail "oh no, bad lilypond"
        Just pc -> return pc
-- todo: throw a real parse error here! 

octUp :: GenParser Char st Char
octUp = char '\''

octDown :: GenParser Char st Char
octDown = char ','

octave = do
    os <- many1 octUp <|> many octDown
    return $ case (length os) of
        0 -> 0
        n -> n * (case (head os) of '\'' -> 1; ',' -> -1)

denom = do 
    spaces
    char '%'
    spaces
    many1 digit

noDenom :: GenParser Char st String
noDenom = do
    return "1"

maybeDenom :: GenParser Char st String
maybeDenom = try denom <|> noDenom

-- but this should NOT accept "%" as it does. \d{6%} is malformed

rationalDur :: GenParser Char st String
rationalDur = do
    string "\\d{"
    spaces
    num <- many1 digit
    denom <- maybeDenom
    spaces
    char '}'
    return $ num ++ "%" ++ denom

durBase :: GenParser Char st String
durBase = 
        many1 digit
    <|> (try $ string "\\breve")
    <|> rationalDur

durDots :: GenParser Char st [Char]
durDots = many $ char '.'

addDots :: Duration -> Int -> Duration
addDots dur numDots = dur * (2 - ((1/2) ^ numDots))

str2dur :: [(String,Duration)]
str2dur = [
    ("1",4)
   ,("2",2)
   ,("4",1)
   ,("8",1/2)
   ,("16",1/4)
   ,("32",1/8)
   ,("64",1/16)
   ,("128",1/32)
   ,("256",1/64)
   ,("\\breve",8)
   ,("0",0)
   ]

noDuration :: GenParser Char st (Maybe Duration)
noDuration = do
    -- don't parse anything
    return Nothing

duration :: GenParser Char st (Maybe Duration)
duration = do
    baseStr <- durBase
    base <- case (lookup baseStr str2dur) of
        Nothing -> return (read baseStr)
        Just b -> return b
    dots <- durDots
    return $ Just $ addDots base (length dots)

maybeDuration :: GenParser Char st (Maybe Duration)
maybeDuration = (try duration) <|> noDuration

-- still need better error message

inputPitch :: GenParser Char st (Pitch',Accidental)
inputPitch = do
    spaces
    (pc,acc) <- pitchClass
    o <- octave
    return $ (RegPitch $ Pitch { _pc = pc, _oct = o, _cents = 0 },acc)

rest :: GenParser Char st (Pitch',Accidental)
rest = do
    spaces
    char 'r'
    return (Rest,Natural) -- ugh

inputPitchEtc :: GenParser Char st (Pitch',Accidental)
inputPitchEtc = (try inputPitch) <|> rest

inputNote :: GenParser Char st (Note,Maybe Duration)
inputNote = do
    spaces
    (p,acc) <- inputPitchEtc
    d <- maybeDuration
    spaces
    return (Note { _pitch = p, _acc = acc, _noteCommands = [], _exprCommands = [] }, d)

notes2music :: [(Note,Maybe Duration)] -> Music' Note
notes2music xs = foldl addToMusic ([],0,1) xs & (^._1)

addToMusic (m, time, _) (note, Just d) = (m ++ [InTime {_val = note, _dur = d, _t = time}], time+d, d)
addToMusic (m, time, prevDur) (note, Nothing) = (m ++ [InTime {_val = note, _dur = prevDur, _t = time}], time+prevDur, prevDur)

parseMusic :: GenParser Char st (Music' Note)
parseMusic = do
    notes <- many inputNote 
    return $ notes2music notes

music :: QuasiQuoter
music = QuasiQuoter { quoteExp = \s -> [| itBetterWork $ runParser parseMusic () "" s |] }

itBetterWork :: Either a b -> b
itBetterWork (Left _) = error "it didn't work :("
itBetterWork (Right b) = b