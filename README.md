Memquery, a small memcache client 

Built this one morning at The Economist when I was having hassle querying
memcache for specific user session keys while building out a caching solution.

Added ability to query slab sizes also.

USAGE EXAMPLES (option parser coming soon):

1. QUERY CACHE KEYS BY REGEX

memquery.rb items n session (look for keys containing the text 'session' in the normal bin(s)

2. QUERY SLAB SIZES

memquery.rb slabbage
