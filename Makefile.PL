use ExtUtils::MakeMaker;
WriteMakefile(
  NAME         => 'TVision::ViewLinks',
  VERSION_FROM => 'lib/TVision/ViewLinks.pm',
  ABSTRACT     => 'Reference-free ring for TGroup/TView using FieldHash + IDs',
  AUTHOR       => 'J. Schneider',
  PREREQ_PM    => { 'Hash::Util::FieldHash' => 0, 'Test2::V0' => 0 },
  LICENSE      => 'mit',
);
