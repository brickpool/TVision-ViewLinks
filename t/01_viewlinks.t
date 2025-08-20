use strict; 
use warnings;

use Test2::V0;
use lib 'lib';

use TVision::ViewLinks qw(
  get_owner get_next get_last get_first
  insert_first insert_after remove_view
  children sanity_check
);

# Dummy objects as wrappers
my $G = bless {}, 'Group';

# empty group
is get_last($G), U(), 'empty: last undef';
is get_first($G), U(), 'empty: first undef';
is [ children($G) ], [], 'empty: no children';
ok sanity_check($G), 'empty: sanity ok';

# insert first
my $A = bless {}, 'View';
insert_first($G, $A);
is get_last($G), $A, 'after first: last == A';
is get_first($G), $A, 'after first: first == A';
is get_next($A), $A, 'single ring: next(A) == A';
like scalar(children($G)), qr/^\d+$/, 'children returns scalar context ok';
is [ children($G) ], [$A], 'children == [A]';
ok sanity_check($G), 'after first: sanity ok';

# insert second at end
my $B = bless {}, 'View';
insert_after($G, get_last($G), $B);
is get_last($G), $B, 'after B: last == B';
is get_first($G), $A, 'after B: first == A';
is [ children($G) ], [$A, $B], 'ring [A, B]';
is get_owner($A), $G, 'owner(A) == G';
is get_owner($B), $G, 'owner(B) == G';
ok sanity_check($G), 'after B: sanity ok';

# insert third at end
my $C = bless {}, 'View';
insert_after($G, get_last($G), $C);
is get_last($G), $C, 'after C: last == C';
is [ children($G) ], [$A, $B, $C], 'ring [A, B, C]';
ok sanity_check($G), 'after C: sanity ok';

# remove middle (B)
ok remove_view($G, $B), 'remove B ok';
is [ children($G) ], [$A, $C], 'ring [A, C]';
is get_last($G), $C, 'last == C';
ok sanity_check($G), 'after remove B: sanity ok';

# remove last (C)
ok remove_view($G, $C), 'remove C ok';
is [ children($G) ], [$A], 'ring [A]';
is get_last($G), $A, 'last == A';
is get_next($A), $A, 'single ring: next(A) == A';
ok sanity_check($G), 'after remove C: sanity ok';

# remove single (A)
ok remove_view($G, $A), 'remove A ok';
is [ children($G) ], [], 'empty again';
is get_last($G), U(), 'last undef again';
is get_first($G), U(), 'first undef again';
ok sanity_check($G), 'empty again: sanity ok';

# attempt removing non-member should be false (no die)
my $X = bless {}, 'View';
ok !remove_view($G, $X), 'remove non-member returns false';

# test with additional parent
my $P = bless {}, 'Group';
insert_first($P, $G);
is [ children($P) ], [$G], 'parent: children == [G]';
insert_first($G, $A);
is [ children($G) ], [$A], 'group: children == [A]';
is get_owner($A), $G, 'owner(A) == G';
insert_after($P, get_last($P), $B);
is [ children($P) ], [$G, $B], 'parent: children == [G, B]';
is get_owner($G), $P, 'owner(G) == P';
is get_owner($B), $P, 'owner(B) == P';

# remove group from parent
ok remove_view($P, $G), 'parent: remove G ok';
is get_owner($A), $G, 'group: owner(A) == G';
is get_first($P), $B, 'parent: first == B';
ok sanity_check($P), 'after remove G: sanity ok';

# remove single (A) from group
ok remove_view($G, $A), 'group: remove A ok';
is [ children($G) ], [], 'group: empty again';
is get_last($G), U(), 'group: last undef again';
is get_first($G), U(), 'group: first undef again';
ok sanity_check($G), 'group empty again: sanity ok';

# remove single (B) from parent
ok remove_view($P, $B), 'parent: remove B ok';
is [ children($P) ], [], 'parent: empty again';
is get_last($P), U(), 'parent: last undef again';
is get_first($P), U(), 'parent: first undef again';
ok sanity_check($P), 'parent empty again: sanity ok';

# done

pass 'all done';
done_testing;
