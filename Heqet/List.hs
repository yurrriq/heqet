{-# LANGUAGE Rank2Types #-}

module Heqet.List where

import Heqet.Types

import Control.Lens

-- like groupBy but doesn't preserve list order,
-- instead grouping as much as possible.
-- makeBucketsBy (==) [1,2,3,1,3,4] -> 
makeBucketsBy :: (a -> a -> Bool) -> [a] -> [[a]]
makeBucketsBy comp xs = foldr f [] xs where
    f x [] = [[x]]
    f x (y:ys) = if x `comp` (head y) -- y can never be []
               then (x:y):ys
               else y:(f x ys)

-- note: does NOT preserve order!
-- or rather, preserves the order of the items
-- we're filtering for, but not the order
-- of the whole list
filteringBy :: (a -> Bool) -> Lens' [a] [a]
filteringBy p = lens (filter p) (\s a -> s++a)

atIndex :: Int -> Lens' [a] a
atIndex i = lens (!! i) (\s a -> (take i s) ++ [a] ++ (drop (i+1) s))

removeAdjacentDuplicatesBy :: (a -> a -> Bool) -> [a] -> [a]
removeAdjacentDuplicatesBy _ [] = []
removeAdjacentDuplicatesBy _ [x] = [x]
removeAdjacentDuplicatesBy f (a:b:xs) = 
    if a `f` b
    then removeAdjacentDuplicatesBy f (a:xs)
    else a:(removeAdjacentDuplicatesBy f (b:xs))