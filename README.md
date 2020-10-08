# speakeasy
A small ruby speach to text client for the google speech API.

## Implementation details
Formats a given audio file into ~1 minute increments, and sets the sampling 
frequency to one recognizable by the google speech API.

Each interval is sent off individually and returns a results that are then
appended to a final results.txt

## Problems with this approach
Because the audio file is cut without regard to any speaking voice, there can be significant data loss.
This could be solved by using fourier transforms to identify when noone is speaking, and to cut at that period.

