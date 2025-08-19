package TVision::ViewLinks;

use strict;
use warnings;

our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(
  set_owner_id set_next_id set_last_id set_current_id
  owner_of next_of last_of current_of first_of children
  insert_after insert_first remove_view sanity_check
);

use Hash::Util::FieldHash qw(fieldhashes id register id_2obj);

# Per-object fields keyed by the wrapper objects.
fieldhashes \my (%owner_id, %next_id, %last_id, %current_id);

#--- internals --------------------------------------------------------------
sub _reg { my ($o) = @_; register($o); return $o }
sub _id  { my ($o) = @_; return defined $o ? (_reg($o), id $o)[1] : undef }

#--- setters ----------------------------------------------------------------
sub set_owner_id   { my ($view,  $group) = @_; $owner_id{$view}    = _id($group) }
sub set_next_id    { my ($view,  $next ) = @_; $next_id{$view}     = _id($next)  }
sub set_last_id    { my ($group, $last ) = @_; $last_id{$group}    = _id($last)  }
sub set_current_id { my ($group, $cur  ) = @_; $current_id{$group} = _id($cur)   }

#--- getters (ID -> object) -------------------------------------------------
sub owner_of   { my ($view)  = @_; my $i = $owner_id{$view};    return defined $i ? id_2obj($i) : undef }
sub next_of    { my ($view)  = @_; my $i = $next_id{$view};     return defined $i ? id_2obj($i) : undef }
sub last_of    { my ($group) = @_; my $i = $last_id{$group};    return defined $i ? id_2obj($i) : undef }
sub current_of { my ($group) = @_; my $i = $current_id{$group}; return defined $i ? id_2obj($i) : undef }

#--- helpers ----------------------------------------------------------------
sub first_of {
    my ($group) = @_;
    my $last = last_of($group) or return undef;
    return next_of($last);
}

sub children {
    my ($group) = @_;
    my $first = first_of($group) or return ();
    my @out; my $v = $first; my $guard = 0; my $max = 100000; # safety
    do {
        push @out, $v;
        $v = next_of($v);
    } while defined($v) && $v != $first && ++$guard < $max;
    return @out;
}

# Insert $new after $target in group's ring. Update owner and last if needed.
sub insert_after {
    my ($group, $target, $new) = @_;
    die "insert_after: target belongs to different group"
        if owner_of($target) && owner_of($target) != $group;

    my $next = next_of($target) // $target;  # single-node ring or unlinked target
    set_next_id($new,   $next);
    set_next_id($target,$new);
    set_owner_id($new,  $group);
    if (defined(my $last = last_of($group))) {
        set_last_id($group, $new) if $target == $last;  # append
    } else {
        # group was empty; establish last
        set_last_id($group, $new);
    }
    return $new;
}

# Insert $new as first child of $group (keeps ring order semantics)
sub insert_first {
    my ($group, $new) = @_;
    if (my $last = last_of($group)) {
        insert_after($group, $last, $new);
    } else {
        set_next_id($new,   $new);   # single-node ring
        set_owner_id($new,  $group);
        set_last_id($group, $new);
    }
    return $new;
}

# Remove $view from group's ring. Returns true if removed.
sub remove_view {
    my ($group, $view) = @_;
    my $last = last_of($group) or return 0;          # empty group
    die "remove_view: node not in this group" 
        if owner_of($view) && owner_of($view) != $group;

    my $first = next_of($last);
    my $pred;
    my $v = $first;
    { 
        do {
            if (next_of($v) && next_of($v) == $view) { $pred = $v; last }
            $v = next_of($v);
        } while $v && $v != $first;
    }
    return 0 unless $pred;                           # not linked

    my $view_next = next_of($view);
    set_next_id($pred, $view_next);

    if ($view == $last) {
        if ($view_next == $view) {
            # was single element
            set_last_id($group, undef);
        } else {
            set_last_id($group, $pred);
        }
    }

    # detach
    set_owner_id($view, undef);
    set_next_id($view,  undef);
    return 1;
}

# Validate ring invariants; return undef on success or an error string
sub sanity_check {
    my ($group) = @_;
    my $last = last_of($group);
    my $first = first_of($group);

    if (!$last) {
        return defined($first) 
            ? 'first set but last undef' 
            : undef;    # empty is fine
    }

    return 'first undef although last is set' unless $first;

    # Walk ring and collect
    my %seen; my @nodes;
    my $v = $first; my $guard = 0; my $max = 100000;
    do {
        return 'owner mismatch' unless owner_of($v) && owner_of($v) == $group;
        my $k = id($v);
        return 'duplicate node in ring' if $seen{$k}++;
        push @nodes, $v;
        $v = next_of($v);
    } while defined($v) && $v != $first && ++$guard < $max;

    return 'ring not closed or too long' if $guard >= $max;
    return 'last not in ring' unless grep { $_ == $last } @nodes;
    return undef;
}

1;

__END__

=encoding utf8

=head1 NAME

TVision::ViewLinks - Referenzfreie Verkettung für TGroup/TView 
(owner/next/last/current)

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

  use TVision::ViewLinks qw(:all);

  my $g = bless {}, 'Group';
  my $a = bless {}, 'View';
  my $b = bless {}, 'View';

  insert_first($g, $a);
  insert_after($g, $a, $b);

  my $first = first_of($g);     # $a
  my @kids  = children($g);     # ($a, $b)
  remove_view($g, $a);

=head1 DESCRIPTION

Dieses Modul bildet die klassische TVision-Topologie von C<TGroup>/C<TView>
(C<owner>, C<next>, C<last>, C<current>) in Perl ab, ohne Perl-Referenzen
zwischen den Wrapper-Objekten zu speichern. Stattdessen werden nur noch
numerische Objekt-IDs in C<fieldhashes> gehalten; die Rückauflösung
(ID→Objekt) erfolgt über die L<Hash::Util::FieldHash>-Registry
(C<register>, C<id>, C<id_2obj>). Dadurch ist die Struktur automatisch
GC-sicher und threadsicher, während die TVision-Invarianten erhalten bleiben.

=head2 Ringlisten-Konvention

Wie im Original: Die Views eines C<TGroup> bilden eine kreisförmige
Liste über C<next>. Der Container hält einen Anker C<last>. 
C<first> ist definiert als C<next(last)>.

=head1 EXPORTS

Das Modul exportiert auf Anfrage (C<@EXPORT_OK>):

  set_owner_id set_next_id set_last_id set_current_id
  owner_of next_of last_of current_of first_of children
  insert_after insert_first remove_view sanity_check

=head1 API

=over 2

=item B<set_owner_id($view, $group)>

=item B<set_next_id($view, $next_view)>

=item B<set_last_id($group, $last_child)>

=item B<set_current_id($group, $current_child)>

Speichern nur IDs, keine Referenzen. C<undef> löscht den link.

=item B<owner_of($view)> / B<next_of($view)> / B<last_of($group)> / 
B<current_of($group)>

Gibt das Objekt zurück oder C<undef>, falls nicht auflösbar.

=item B<first_of($group)>

Gibt C<next(last($group))> oder C<undef> (leere Gruppe).

=item B<children($group)>

Liefert die Views in Z-Reihenfolge (einmal um den Ring ab C<first>).

=item B<insert_after($group, $target, $new_view)>

Fügt ein und setzt C<owner>; aktualisiert C<last>, falls C<$target> das
letzte View war oder die Gruppe leer war.

=item B<insert_first($group, $new_view)>

Fügt als erstes Kind ein (beachtet Ring-Invarianten).

=item B<remove_view($group, $view)>

Löst C<$view> aus der Ringliste, passt C<last> an und setzt C<owner>/<next>
auf C<undef>. Liefert wahr bei Erfolg.

=item B<sanity_check($group)>

Prüft die wichtigsten Invarianten; liefert C<undef> bei Erfolg oder einen
Fehlertext.

=back

=head1 INVARIANTEN

=over 2

=item * Leere Gruppe: C<last == undef>, C<first == undef>.

=item * Nicht leer: C<first == next(last)>.

=item * Einzelelement-Ring: C<next(first) == first> und C<last == first>.

=item * Alle Kinder besitzen C<owner == $group> und bilden eine zirkuläre Liste.

=back

=head1 IMPLEMENTIERUNGSHINWEISE

=over 2

=item * Die Registry aus L<Hash::Util::FieldHash> (C<register>, C<id>, 
C<id_2obj>) ermöglicht referenzfreie Speicherung und sichere Rückauflösung 
(GC- und threadsicher).

=item * Es werden bewusst keine C<Scalar::Util::weaken>-Verweise benötigt,
da ausschließlich IDs gespeichert werden.

=back

=head1 AUTOR

J. Schneider

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 J. Schneider.

Dieses Dokument darf unter den gleichen Bedingungen wie das Projekt 
F<github.com/brickpool/TVision> verwendet und angepasst werden.

=cut
