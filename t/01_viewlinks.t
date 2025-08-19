use strict; 
use warnings;

use Test2::V0;
use lib 'lib';

use TVision::ViewLinks qw(
  insert_first insert_after remove_view
  owner_of next_of last_of first_of children sanity_check
);

# Dummy objects as wrappers
my $G = bless {}, 'Group';

# empty group
is last_of($G), U(), 'empty: last undef';
is first_of($G), U(), 'empty: first undef';
is [ children($G) ], [], 'empty: no children';
ok !sanity_check($G), 'empty: sanity ok';

# insert first
my $A = bless {}, 'View';
insert_first($G, $A);
is last_of($G), $A, 'after first: last == A';
is first_of($G), $A, 'after first: first == A';
is next_of($A), $A, 'single ring: next(A) == A';
like scalar(children($G)), qr/^2?\d*$/, 'children returns scalar context ok';
is [ children($G) ], [$A], 'children == [A]';
ok !sanity_check($G), 'after first: sanity ok';

# insert second at end
my $B = bless {}, 'View';
insert_after($G, last_of($G), $B);
is last_of($G), $B, 'after B: last == B';
is first_of($G), $A, 'after B: first == A';
is [ children($G) ], [$A, $B], 'ring [A, B]';
is owner_of($A), $G, 'owner(A) == G';
is owner_of($B), $G, 'owner(B) == G';
ok !sanity_check($G), 'after B: sanity ok';

# insert third at end
my $C = bless {}, 'View';
insert_after($G, last_of($G), $C);
is last_of($G), $C, 'after C: last == C';
is [ children($G) ], [$A, $B, $C], 'ring [A, B, C]';
ok !sanity_check($G), 'after C: sanity ok';

# remove middle (B)
ok remove_view($G, $B), 'remove B ok';
is [ children($G) ], [$A, $C], 'ring [A, C]';
is last_of($G), $C, 'last == C';
ok !sanity_check($G), 'after remove B: sanity ok';

# remove last (C)
ok remove_view($G, $C), 'remove C ok';
is [ children($G) ], [$A], 'ring [A]';
is last_of($G), $A, 'last == A';
is next_of($A), $A, 'single ring: next(A) == A';
ok !sanity_check($G), 'after remove C: sanity ok';

# remove single (A)
ok remove_view($G, $A), 'remove A ok';
is [ children($G) ], [], 'empty again';
is last_of($G), U(), 'last undef again';
is first_of($G), U(), 'first undef again';
ok !sanity_check($G), 'empty again: sanity ok';

# attempt removing non-member should be false (no die)
my $X = bless {}, 'View';
ok !remove_view($G, $X), 'remove non-member returns false';

# done

pass 'all done';
done_testing;
