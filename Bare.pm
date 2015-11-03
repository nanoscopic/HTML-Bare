#!/usr/bin/perl -w
package HTML::Bare;

use Carp;
use strict;
use vars qw( @ISA @EXPORT @EXPORT_OK $VERSION );
use utf8;
require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);
$VERSION = "0.04";
use vars qw($VERSION *AUTOLOAD);

*AUTOLOAD = \&XML::Bare::AUTOLOAD;
bootstrap HTML::Bare $VERSION;

@EXPORT = qw( );
@EXPORT_OK = qw( xget merge clean add_node del_node find_node del_node forcearray del_by_perl htmlin xval find_by_tagname find_by_id find_by_att nav unmix simplify complicate );

=head1 NAME

HTML::Bare - Minimal HTML parser implemented via a C state engine

=head1 VERSION

0.04

=cut

sub new {
  my $class = shift; 
  my $self  = { @_ };
  
  $self->{'i'} = 0;
  if( $self->{ 'text' } ) {
    if( $self->{'unsafe'} ) {
        $self->{'parser'} = HTML::Bare::c_parse_unsafely( $self->{'text'} );
    }
    else {
        $self->{'parser'} = HTML::Bare::c_parse( $self->{'text'} );
    }
  }
  else {
    my $res = open( my $HTML, $self->{ 'file' } );
    if( !$res ) {
      $self->{ 'html' } = 0;
      return 0;
    }
    {
      local $/ = undef;
      $self->{'text'} = <$HTML>;
    }
    close( $HTML );
    #open(DX,">dumpx");
    #print DX $self->{'text'}, "\n---\n";
    #close(DX);
    $self->{'parser'} = HTML::Bare::c_parse( $self->{'text'} );
  }
  bless $self, "HTML::Bare::Object";
  return $self if( !wantarray );
  return ( $self, ( $self->{'simple'} ? $self->simple() : $self->parse() ) );
}

sub simple {
    return new( @_, simple => 1 );
}

package HTML::Bare::Object;

use Carp;
use strict;

# Stubs ( to allow these functions to be used via an object as well, not just via import or namespace )
sub find_by_perl { shift; return HTML::Bare::find_by_perl( @_ ); }
sub find_node { shift; return HTML::Bare::find_node( @_ ); }
sub simplify { shift; return XML::Bare::simplify( @_ ); }
sub complicate { shift; return XML::Bare::complicate( @_ ); }

sub DESTROY {
  my $self = shift;
  #use Data::Dumper;
  #print Dumper( $self );
  undef $self->{'text'};
  undef $self->{'i'};
  $self->cleanup();
  $self->free_tree();
  undef $self->{'parser'};
}

sub read_more {
    my $self = shift;
    my %p = ( @_ );
    my $i = $self->{'i'}++;
    if( $p{'text'} ) {
        $self->{"text$i"} = $p{'text'};
        #open(DX,">>dumpx");
        #print DX $p{'text'}, "\n---\n";
        #close(DX);
        HTML::Bare::c_parse_more( $self->{"text$i"}, $self->{'parser'} );
    }
    my $res = HTML::Bare::html2obj( $self->{'parser'} );
    $self->{ 'html' } = $res;
    return $self->{'html'};
}

sub raw {
    my ( $self, $node ) = @_;
    my $i = $node->{'_i'};
    my $z = $node->{'_z'};
    #return HTML::Bare::c_raw( $self->{'parser'}, $i, $z );
    return substr( $self->{'text'}, $i - 1, $z - $i + 2 );
}

sub parse {
  my $self = shift;
  
  my $res = HTML::Bare::html2obj( $self->{'parser'} );
  
  if( defined( $self->{'scheme'} ) ) {
    $self->{'xbs'} = new HTML::Bare( %{ $self->{'scheme'} } );
  }
  if( defined( $self->{'xbs'} ) ) {
    my $xbs = $self->{'xbs'};
    my $ob = $xbs->parse();
    $self->{'xbso'} = $ob;
    readxbs( $ob );
  }
  
  #if( !ref( $res ) && $res < 0 ) { croak "Error at ".$self->lineinfo( -$res ); }
  $self->{ 'html' } = $res;
  
  if( defined( $self->{'xbso'} ) ) {
    my $ob = $self->{'xbso'};
    my $cres = $self->check( $res, $ob );
    croak( $cres ) if( $cres );
  }
  
  return $self->{ 'html' };
}

sub get_parse_position {
  my $self = shift;
  return HTML::Bare::c_get_parse_position( $self->{'parser'} );
}

sub stop_outside {
  my $self = shift;
  return HTML::Bare::c_stop_outside( $self->{'parser'} );
}

# html bare schema
sub check {
  my ( $self, $node, $scheme, $parent ) = @_;
  
  my $fail = '';
  if( ref( $scheme ) eq 'ARRAY' ) {
    for my $one ( @$scheme ) {
      my $res = $self->checkone( $node, $one, $parent );
      return 0 if( !$res );
      $fail .= "$res\n";
    }
  }
  else { return $self->checkone( $node, $scheme, $parent ); }
  return $fail;
}

sub checkone {
  my ( $self, $node, $scheme, $parent ) = @_;
  
  for my $key ( keys %$node ) {
    next if( substr( $key, 0, 1 ) eq '_' || $key eq '_att' || $key eq 'comment' );
    if( $key eq 'value' ) {
      my $val = $node->{ 'value' };
      my $regexp = $scheme->{'value'};
      if( $regexp ) {
        if( $val !~ m/^($regexp)$/ ) {   
          my $linfo = $self->lineinfo( $node->{'_i'} );
          return "Value of '$parent' node ($val) does not match /$regexp/ [$linfo]";
        }
      }
      next;
    }
    my $sub = $node->{ $key };
    my $ssub = $scheme->{ $key };
    if( !$ssub ) { #&& ref( $schemesub ) ne 'HASH'
      my $linfo = $self->lineinfo( $sub->{'_i'} );
      return "Invalid node '$key' in html [$linfo]";
    }
    if( ref( $sub ) eq 'HASH' ) {
      my $res = $self->check( $sub, $ssub, $key );
      return $res if( $res );
    }
    if( ref( $sub ) eq 'ARRAY' ) {
      my $asub = $ssub;
      if( ref( $asub ) eq 'ARRAY' ) {
        $asub = $asub->[0];
      }
      if( $asub->{'_t'} ) {
        my $max = $asub->{'_max'} || 0;
        if( $#$sub >= $max ) {
          my $linfo = $self->lineinfo( $sub->[0]->{'_i'} );
          return "Too many nodes of type '$key'; max $max; [$linfo]"
        }
        my $min = $asub->{'_min'} || 0;
        if( ($#$sub+1)<$min ) {
          my $linfo = $self->lineinfo( $sub->[0]->{'_i'} );
          return "Not enough nodes of type '$key'; min $min [$linfo]"
        }
      }
      for( @$sub ) {
        my $res = $self->check( $_, $ssub, $key );
        return $res if( $res );
      }
    }
  }
  if( my $dem = $scheme->{'_demand'} ) {
    for my $req ( @{$scheme->{'_demand'}} ) {
      my $ck = $node->{ $req };
      if( !$ck ) {
        my $linfo = $self->lineinfo( $node->{'_i'} );
        return "Required node '$req' does not exist [$linfo]"
      }
      if( ref( $ck ) eq 'ARRAY' ) {
        my $linfo = $self->lineinfo( $node->{'_i'} );
        return "Required node '$req' is empty array [$linfo]" if( $#$ck == -1 );
      }
    }
  }
  return 0;
}

sub simple {
  my $self = shift;
  
  my $res = HTML::Bare::html2obj_simple( $self->{'parser'} );#$self->html2obj();
  
  if( !ref( $res ) && $res < 0 ) { croak "Error at ".$self->lineinfo( -$res ); }
  $self->{ 'html' } = $res;
  
  return $res;
}

sub add_node {
  my ( $self, $node, $name ) = @_;
  my @newar;
  my %blank;
  $node->{ 'multi_'.$name } = \%blank if( ! $node->{ 'multi_'.$name } );
  $node->{ $name } = \@newar if( ! $node->{ $name } );
  my $newnode = new_node( 0, splice( @_, 3 ) );
  push( @{ $node->{ $name } }, $newnode );
  return $newnode;
}

sub add_node_after {
  my ( $self, $node, $prev, $name ) = @_;
  my @newar;
  my %blank;
  $node->{ 'multi_'.$name } = \%blank if( ! $node->{ 'multi_'.$name } );
  $node->{ $name } = \@newar if( ! $node->{ $name } );
  my $newnode = $self->new_node( splice( @_, 4 ) );
  
  my $cur = 0;
  for my $anode ( @{ $node->{ $name } } ) {
    $anode->{'_pos'} = $cur if( !$anode->{'_pos'} );
    $cur++;
  }
  my $opos = $prev->{'_pos'};
  for my $anode ( @{ $node->{ $name } } ) {
    $anode->{'_pos'}++ if( $anode->{'_pos'} > $opos );
  }
  $newnode->{'_pos'} = $opos + 1;
  
  push( @{ $node->{ $name } }, $newnode );
  
  return $newnode;
}

sub del_node {
  my $self = shift;
  my $node = shift;
  my $name = shift;
  my %match = @_;
  $node = $node->{ $name };
  return if( !$node );
  for( my $i = 0; $i <= $#$node; $i++ ) {
    my $one = $node->[ $i ];
    foreach my $key ( keys %match ) {
      my $val = $match{ $key };
      if( $one->{ $key }->{'value'} eq $val ) {
        delete $node->[ $i ];
      }
    }
  }
}

# Created a node of HTML hash with the passed in variables already set
sub new_node {
  my $self  = shift;
  my %parts = @_;
  
  my %newnode;
  foreach( keys %parts ) {
    my $val = $parts{$_};
    if( m/^_/ || ref( $val ) eq 'HASH' ) {
      $newnode{ $_ } = $val;
    }
    else {
      $newnode{ $_ } = { value => $val };
    }
  }
  
  return \%newnode;
}

sub hash2html {
    my ( $node, $name ) = @_;
    my $ref = ref( $node );
    return '' if( $name && $name =~ m/^\_/ );
    my $txt = $name ? "<$name>" : '';
    if( $ref eq 'ARRAY' ) {
       $txt = '';
       for my $sub ( @$node ) {
           $txt .= hash2html( $sub, $name );
       }
       return $txt;
    }
    elsif( $ref eq 'HASH' ) {
       for my $key ( keys %$node ) {
           $txt .= hash2html( $node->{ $key }, $key );
       }
    }
    else {
        $node ||= '';
        if( $node =~ /[<]/ ) { $txt .= '<![CDATA[' . $node . ']]>'; }
        else { $txt .= $node; }
    }
    if( $name ) {
        $txt .= "</$name>";
    }
        
    return $txt;
}

# Save an HTML hash tree into a file
sub save {
  my $self = shift;
  return if( ! $self->{ 'html' } );
  
  my $html = $self->html( $self->{'html'} );
  
  my $len;
  {
    use bytes;  
    $len = length( $html );
  }
  return if( !$len );
  
  # This is intentionally just :utf8 and not :encoding(UTF-8)
  # :encoding(UTF-8) checks the data for actually being valid UTF-8, and doing so would slow down the file write
  # See http://perldoc.perl.org/functions/binmode.html
  
  my $os = $^O;
  my $F;
  
  # Note on the following conditional OS check... WTF? This is total bullshit.
  if( $os eq 'MSWin32' ) {
      open( $F, '>:utf8', $self->{ 'file' } );
      binmode $F;
  }
  else {
      open( $F, '>', $self->{ 'file' } );
      binmode $F, ':utf8';
  }
  print $F $html;
  
  seek( $F, 0, 2 );
  my $cursize = tell( $F );
  if( $cursize != $len ) { # concurrency; we are writing a smaller file
    warn "Truncating File $self->{'file'}";
    `cp $self->{'file'} $self->{'file'}.bad`;
    truncate( F, $len );
  }
  seek( $F, 0, 2 );
  $cursize = tell( $F );
  if( $cursize != $len ) { # still not the right size even after truncate??
    die "Write problem; $cursize != $len";
  }
  close $F;
}

sub html {
  my ( $self, $obj, $name ) = @_;
  if( !$name ) {
    my %hash;
    $hash{0} = $obj;
    return HTML::Bare::obj2html( \%hash, '', 0 );
  }
  my %hash;
  $hash{$name} = $obj;
  return HTML::Bare::obj2html( \%hash, '', 0 );
}

sub htmlcol {
  my ( $self, $obj, $name ) = @_;
  my $pre = '';
  if( $self->{'style'} ) {
    $pre = "<style type='text/css'>\@import '$self->{'style'}';</style>";
  }
  if( !$name ) {
    my %hash;
    $hash{0} = $obj;
    return $pre.obj2htmlcol( \%hash, '', 0 );
  }
  my %hash;
  $hash{$name} = $obj;
  return $pre.obj2htmlcol( \%hash, '', 0 );
}

sub lineinfo {
  my $self = shift;
  my $res  = shift;
  my $line = 1;
  my $j = 0;
  for( my $i=0;$i<$res;$i++ ) {
    my $let = substr( $self->{'text'}, $i, 1 );
    if( ord($let) == 10 ) {
      $line++;
      $j = $i;
    }
  }
  my $part = substr( $self->{'text'}, $res, 10 );
  $part =~ s/\n//g;
  $res -= $j;
  if( $self->{'offset'} ) {
    my $off = $self->{'offset'};
    $line += $off;
    return "$off line $line char $res \"$part\"";
  }
  return "line $line char $res \"$part\"";
}

sub free_tree { my $self = shift; HTML::Bare::free_tree_c( $self->{'parser'} ); }
sub cleanup { my $self = shift; HTML::Bare::cleanup_c( $self->{'parser'} ); }

package HTML::Bare;

sub find_node {
  my $node = shift;
  my $name = shift;
  my %match = @_;
  return 0 if( ! defined $node );
  $node = $node->{ $name } or return 0;
  $node = [ $node ] if( ref( $node ) eq 'HASH' );
  if( ref( $node ) eq 'ARRAY' ) {
    for( my $i = 0; $i <= $#$node; $i++ ) {
      my $one = $node->[ $i ];
      for my $key ( keys %match ) {
        my $val = $match{ $key };
        croak('undefined value in find') unless defined $val;
        if( $one->{ $key }{'value'} eq $val ) {
          return $node->[ $i ];
        }
      }
    }
  }
  return 0;
}

sub xget {
  my $hash = shift;
  return map $_->{'value'}, @{$hash}{@_};
}

sub forcearray {
  my $ref = shift;
  return [] if( !$ref );
  return $ref if( ref( $ref ) eq 'ARRAY' );
  return [ $ref ];
}

sub merge {
  # shift in the two array references as well as the field to merge on
  my ( $a, $b, $id ) = @_;
  my %hash = map { $_->{ $id } ? ( $_->{ $id }->{ 'value' } => $_ ) : ( 0 => 0 ) } @$a;
  for my $one ( @$b ) {
    next if( !$one->{ $id } );
    my $short = $hash{ $one->{ $id }->{ 'value' } };
    next if( !$short );
    foreach my $key ( keys %$one ) {
      next if( $key eq '_pos' || $key eq 'id' );
      my $cur = $short->{ $key };
      my $add = $one->{ $key };
      if( !$cur ) { $short->{ $key } = $add; }
      else {
        my $type = ref( $cur );
        if( $type eq 'HASH' ) {
          my @arr;
          $short->{ $key } = \@arr;
          push( @arr, $cur );
        }
        if( ref( $add ) eq 'HASH' ) {
          push( @{$short->{ $key }}, $add );
        }
        else { # we are merging an array
          push( @{$short->{ $key }}, @$add );
        }
      }
      # we need to deal with the case where this node
      # is already there, either alone or as an array
    }
  }
  return $a;  
}

sub clean {
  my $ob = new HTML::Bare( @_ );
  my $root = $ob->parse();
  if( $ob->{'save'} ) {
    $ob->{'file'} = $ob->{'save'} if( "$ob->{'save'}" ne "1" );
    $ob->save();
    return;
  }
  return $ob->html( $root );
}

sub htmlin {
  my $text = shift;
  my %ops = ( @_ );
  my $ob = new HTML::Bare( text => $text );
  my $simple = $ob->simple();
  if( !$ops{'keeproot'} ) {
    my @keys = keys %$simple;
    my $first = $keys[0];
    $simple = $simple->{ $first } if( $first );
  }
  return $simple;
}

sub tohtml {
  my %ops = ( @_ );
  my $ob = new HTML::Bare( %ops );
  return $ob->html( $ob->parse(), $ops{'root'} || 'html' );
}

sub readxbs { # xbs = html bare schema
  my $node = shift;
  my @demand;
  for my $key ( keys %$node ) {
    next if( substr( $key, 0, 1 ) eq '_' || $key eq '_att' || $key eq 'comment' );
    if( $key eq 'value' ) {
      my $val = $node->{'value'};
      delete $node->{'value'} if( $val =~ m/^\W*$/ );
      next;
    }
    my $sub = $node->{ $key };
    
    if( $key =~ m/([a-z_]+)([^a-z_]+)/ ) {
      my $name = $1;
      my $t = $2;
      my $min;
      my $max;
      if( $t eq '+' ) {
        $min = 1;
        $max = 1000;
      }
      elsif( $t eq '*' ) {
        $min = 0;
        $max = 1000;
      }
      elsif( $t eq '?' ) {
        $min = 0;
        $max = 1;
      }
      elsif( $t eq '@' ) {
        $name = 'multi_'.$name;
        $min = 1;
        $max = 1;
      }
      elsif( $t =~ m/\{([0-9]+),([0-9]+)\}/ ) {
        $min = $1;
        $max = $2;
        $t = 'r'; # range
      }
      
      if( ref( $sub ) eq 'HASH' ) {
        my $res = readxbs( $sub );
        $sub->{'_t'} = $t;
        $sub->{'_min'} = $min;
        $sub->{'_max'} = $max;
      }
      if( ref( $sub ) eq 'ARRAY' ) {
        for my $item ( @$sub ) {
          my $res = readxbs( $item );
          $item->{'_t'} = $t;
          $item->{'_min'} = $min;
          $item->{'_max'} = $max;
        }
      }
      
      push( @demand, $name ) if( $min );
      $node->{$name} = $node->{$key};
      delete $node->{$key};
    }
    else {
      if( ref( $sub ) eq 'HASH' ) {
        readxbs( $sub );
        $sub->{'_t'} = 'r';
        $sub->{'_min'} = 1;
        $sub->{'_max'} = 1;
      }
      if( ref( $sub ) eq 'ARRAY' ) {
        for my $item ( @$sub ) {
          readxbs( $item );
          $item->{'_t'} = 'r';
          $item->{'_min'} = 1;
          $item->{'_max'} = 1;
        }
      }
      
      push( @demand, $key );
    }
  }
  if( @demand ) { $node->{'_demand'} = \@demand; }
}

sub find_by_perl {
  my $arr = shift;
  my $cond = shift;
  
  my @res;
  if( ref( $arr ) eq 'ARRAY' ) {
      $cond =~ s/-([a-z_]+)/\$ob->\{'$1'\}->\{'value'\}/gi;
      foreach my $ob ( @$arr ) { push( @res, $ob ) if( eval( $cond ) ); }
  }
  else {
      $cond =~ s/-([a-z_]+)/\$arr->\{'$1'\}->\{'value'\}/gi;
      push( @res, $arr ) if( eval( $cond ) );
  }
  return \@res;
}

sub del_by_perl {
  my $arr = shift;
  my $cond = shift;
  $cond =~ s/-value/\$ob->\{'value'\}/g;
  $cond =~ s/-([a-z]+)/\$ob->\{'$1'\}->\{'value'\}/g;
  my @res;
  for( my $i = 0; $i <= $#$arr; $i++ ) {
    my $ob = $arr->[ $i ];
    delete $arr->[ $i ] if( eval( $cond ) );
  }
  return \@res;
}

sub newhash { shift; return { value => shift }; }

sub xval {
  return $_[0] ? $_[0]->{'value'} : ( $_[1] || '' );
}

sub obj2html {
  my ( $objs, $name, $pad, $level, $pdex ) = @_;
  $level  = 0  if( !$level );
  $pad    = '' if(  $level <= 2 );
  my $html = '';
  my $att = '';
  my $imm = 1;
  return '' if( !$objs );
  #return $objs->{'_raw'} if( $objs->{'_raw'} );
  my @dex = sort { 
    my $oba = $objs->{ $a };
    my $obb = $objs->{ $b };
    my $posa = 0;
    my $posb = 0;
    $oba = $oba->[0] if( ref( $oba ) eq 'ARRAY' );
    $obb = $obb->[0] if( ref( $obb ) eq 'ARRAY' );
    if( ref( $oba ) eq 'HASH' ) { $posa = $oba->{'_pos'} || 0; }
    if( ref( $obb ) eq 'HASH' ) { $posb = $obb->{'_pos'} || 0; }
    return $posa <=> $posb;
  } keys %$objs;
  for my $i ( @dex ) {
    my $obj  = $objs->{ $i } || '';
    my $type = ref( $obj );
    if( $type eq 'ARRAY' ) {
      $imm = 0;
      
      my @dex2 = sort { 
        if( !$a ) { return 0; }
        if( !$b ) { return 0; }
        if( ref( $a ) eq 'HASH' && ref( $b ) eq 'HASH' ) {
          my $posa = $a->{'_pos'};
          my $posb = $b->{'_pos'};
          if( !$posa ) { $posa = 0; }
          if( !$posb ) { $posb = 0; }
          return $posa <=> $posb;
        }
        return 0;
      } @$obj;
      
      for my $j ( @dex2 ) {
        $html .= obj2html( $j, $i, $pad.'  ', $level+1, $#dex );
      }
    }
    elsif( $type eq 'HASH' && $i !~ /^_/ ) {
      if( $obj->{ '_att' } ) {
        my $val = $obj->{'value'} || '';
        $att .= ' ' . $i . '="' . $val . '"' if( $i !~ /^_/ );;
      }
      else {
        $imm = 0;
        $html .= obj2html( $obj , $i, $pad.'  ', $level+1, $#dex );
      }
    }
    else {
      if( $i eq 'comment' ) { $html .= '<!--' . $obj . '-->' . "\n"; }
      elsif( $i eq 'value' ) {
        if( $level > 1 ) { # $#dex < 4 && 
          if( $obj && $obj =~ /[<>&;]/ ) { $html .= '<![CDATA[' . $obj . ']]>'; }
          else { $html .= $obj if( $obj =~ /\S/ ); }
        }
      }
      elsif( $i =~ /^_/ ) {}
      else { $html .= '<' . $i . '>' . $obj . '</' . $i . '>'; }
    }
  }
  my $pad2 = $imm ? '' : $pad;
  my $cr = $imm ? '' : "\n";
  if( substr( $name, 0, 1 ) ne '_' ) {
    if( $name ) {
      if( $html ) {
        $html = $pad . '<' . $name . $att . '>' . $cr . $html . $pad2 . '</' . $name . '>';
      }
      else {
        $html = $pad . '<' . $name . $att . ' />';
      }
    }
    return $html."\n" if( $level > 1 );
    return $html;
  }
  return '';
}

sub obj2htmlcol {
  my ( $objs, $name, $pad, $level, $pdex ) = @_;
    
  my $less = "<span class='ang'>&lt;</span>";
  my $more = "<span class='ang'>></span>";
  my $tn0 = "<span class='tname'>";
  my $tn1 = "</span>";
  my $eq0 = "<span class='eq'>";
  my $eq1 = "</span>";
  my $qo0 = "<span class='qo'>";
  my $qo1 = "</span>";
  my $sp0 = "<span class='sp'>";
  my $sp1 = "</span>";
  my $cd0 = "";
  my $cd1 = "";
  
  $level = 0 if( !$level );
  $pad = '' if( $level == 1 );
  my $html  = '';
  my $att  = '';
  my $imm  = 1;
  return '' if( !$objs );
  my @dex = sort { 
    my $oba = $objs->{ $a };
    my $obb = $objs->{ $b };
    my $posa = 0;
    my $posb = 0;
    $oba = $oba->[0] if( ref( $oba ) eq 'ARRAY' );
    $obb = $obb->[0] if( ref( $obb ) eq 'ARRAY' );
    if( ref( $oba ) eq 'HASH' ) { $posa = $oba->{'_pos'} || 0; }
    if( ref( $obb ) eq 'HASH' ) { $posb = $obb->{'_pos'} || 0; }
    return $posa <=> $posb;
  } keys %$objs;
  
  if( $objs->{'_cdata'} ) {
    my $val = $objs->{'value'};
    $val =~ s/^(\s*\n)+//;
    $val =~ s/\s+$//;
    $val =~ s/&/&amp;/g;
    $val =~ s/</&lt;/g;
    $objs->{'value'} = $val;
    #$html = "$less![CDATA[<div class='node'><div class='cdata'>$val</div></div>]]$more";
    $cd0 = "$less![CDATA[<div class='node'><div class='cdata'>";
    $cd1 = "</div></div>]]$more";
  }
  for my $i ( @dex ) {
    my $obj  = $objs->{ $i } || '';
    my $type = ref( $obj );
    if( $type eq 'ARRAY' ) {
      $imm = 0;
      
      my @dex2 = sort { 
        if( !$a ) { return 0; }
        if( !$b ) { return 0; }
        if( ref( $a ) eq 'HASH' && ref( $b ) eq 'HASH' ) {
          my $posa = $a->{'_pos'};
          my $posb = $b->{'_pos'};
          if( !$posa ) { $posa = 0; }
          if( !$posb ) { $posb = 0; }
          return $posa <=> $posb;
        }
        return 0;
      } @$obj;
      
      for my $j ( @dex2 ) { $html .= obj2html( $j, $i, $pad.'&nbsp;&nbsp;', $level+1, $#dex ); }
    }
    elsif( $type eq 'HASH' && $i !~ /^_/ ) {
      if( $obj->{ '_att' } ) {
        my $val = $obj->{ 'value' };
        $val =~ s/</&lt;/g;
        if( $val eq '' ) {
          $att .= " <span class='aname'>$i</span>" if( $i !~ /^_/ );
        }
        else {
          $att .= " <span class='aname'>$i</span>$eq0=$eq1$qo0\"$qo1$val$qo0\"$qo1" if( $i !~ /^_/ );
        }
      }
      else {
        $imm = 0;
        $html .= obj2html( $obj , $i, $pad.'&nbsp;&nbsp;', $level+1, $#dex );
      }
    }
    else {
      if( $i eq 'comment' ) { $html .= "$less!--" . $obj . "--$more" . "<br>\n"; }
      elsif( $i eq 'value' ) {
        if( $level > 1 ) {
          if( $obj && $obj =~ /[<>&;]/ && ! $objs->{'_cdata'} ) { $html .= "$less![CDATA[$obj]]$more"; }
          else { $html .= $obj if( $obj =~ /\S/ ); }
        }
      }
      elsif( $i =~ /^_/ ) {}
      else { $html .= "$less$tn0$i$tn1$more$obj$less/$tn0$i$tn1$more"; }
    }
  }
  my $pad2 = $imm ? '' : $pad;
  if( substr( $name, 0, 1 ) ne '_' ) {
    if( $name ) {
      if( $imm ) {
        if( $html =~ /\S/ ) {
          $html = "$sp0$pad$sp1$less$tn0$name$tn1$att$more$cd0$html$cd1$less/$tn0$name$tn1$more";
        }
        else {
          $html = "$sp0$pad$sp1$less$tn0$name$tn1$att/$more";
        }
      }
      else {
        if( $html =~ /\S/ ) {
          $html = "$sp0$pad$sp1$less$tn0$name$tn1$att$more<div class='node'>$html</div>$sp0$pad$sp1$less/$tn0$name$tn1$more";
        }
        else { $html = "$sp0$pad$sp1$less$tn0$name$tn1$att/$more"; }
      }
    }
    $html .= "<br>" if( $objs->{'_br'} );
    if( $objs->{'_note'} ) {
      $html .= "<br>";
      my $note = $objs->{'_note'}{'value'};
      my @notes = split( /\|/, $note );
      for( @notes ) {
        $html .= "<div class='note'>$sp0$pad$sp1<span class='com'>&lt;!--</span> $_ <span class='com'>--></span></div>";
      }
    }
    return $html."<br>\n" if( $level );
    return $html;
  }
  return '';
}

# a.b.c@att=10
# a.b.@att=10
# a.b.@value=10 ( value of node )
# a.*.c
sub nav {
    my ( $node, $navtext ) = @_;
    my @parts = split( /\./, $navtext );
    my $curnodes;
    
    if( ref( $node ) eq 'HASH' ) {
        $curnodes = [ $node ];
    }
    else {
        $curnodes = $node;
    }
    my $nextnodes = [];
    
    # make sure we haven't passed in references to arrays of nodes
    my $fix = 0;
    for my $curnode ( @$curnodes ) {
        if( ref( $curnode ) eq 'ARRAY' ) {
            $fix = 1;
            last;
        }
    }
    if( $fix ) {
        for my $curnode ( @$curnodes ) {
            if( ref( $curnode ) eq 'ARRAY' ) {
                push( @$nextnodes, @$curnode );
            }
            else {
                push( @$nextnodes, $curnode );
            }
        }
        $curnodes = $nextnodes;
        $nextnodes = [];
    }
    
    for my $part ( @parts ) {
        #print Dumper( $curnodes );
        if( $part =~ m/^([a-zA-Z]*)\@([a-zA-Z]+)=(.+)/ ) {
            my $subname = $1;
            my $att = $2;
            my $val = $3;
            if( $subname ) {
                # first collect named nodes
                if( scalar @$curnodes == 1 ) {
                    $curnodes = forcearray( $curnodes->[0]{ $subname } );
                }
                else {
                    for my $curnode ( @$curnodes ) {
                        my $morenodes = forcearray( $curnode->{ $subname } );
                        push( @$nextnodes, @$morenodes )
                    }
                    $curnodes = $nextnodes;
                    $nextnodes = [];
                }
                # then ditch the ones that don't have the matching attribute ( done automatically by the below code outside of if )
            }
            else {
                # collect -all- subnodes, regardless of name ( note this methodology is not terribly efficient )
                for my $curnode ( @$curnodes ) {
                    # note curnode will never be an array at this point
                    for my $key ( keys %$curnode ) {
                        next if( $key =~ m/^_/ );
                        next if( $key eq 'value' );
                        my $morenodes = forcearray( $curnode->{ $key } );
                        push( @$nextnodes, @$morenodes );
                    }
                }
            }
            
            # go through all subnodes, finding the ones that have the matching attribute
            if( $att eq 'value' ) {
                for my $curnode ( @$curnodes ) {
                    push( @$nextnodes, $curnode ) if( $curnode->{'value'} eq $val );
                }
            }
            else {
                for my $curnode ( @$curnodes ) {
                    push( @$nextnodes, $curnode ) if( $curnode->{ $att }{'value'} eq $val );
                }
            }
        }
        elsif( $part eq '*' ) {
            for my $curnode ( @$curnodes ) {
                # note curnode will never be an array at this point
                for my $key ( keys %$curnode ) {
                    next if( $key =~ m/^_/ );
                    next if( $key eq 'value' );
                    my $morenodes = forcearray( $curnode->{ $key } );
                    push( @$nextnodes, @$morenodes );
                }
            }
        }
        else {
            if( scalar @$curnodes == 1 ) {
                $nextnodes = forcearray( $curnodes->[0]{ $part } );
                #print Dumper( $curnodes );
            }
            else {
                for my $curnode ( @$curnodes ) {
                    my $morenodes = forcearray( $curnode->{ $part } );
                    push( @$nextnodes, @$morenodes )
                }
            }
        }
        $curnodes = $nextnodes;
        $nextnodes = [];
        last if( ! scalar @$curnodes );
    }
    return $curnodes;
}

sub find_by_tagname {
    my ( $node, $tagname, $depth ) = @_;
    my @nodes;
    if( !$depth ) { $depth = 400; }
    my $rx = 0;
    if( $tagname =~ m/\~(.+)/ ) {
      $tagname = $1;
      $rx = 1;
    }
    find_by_tagnamer( $node, \@nodes, $tagname, $rx, $depth );
    return \@nodes;
}
sub find_by_tagnamer {
    my ( $node, $res, $tagname, $rx, $depth ) = @_;
    if( ref( $node ) eq 'HASH' ) {
        return if( $node->{'_att'} );
        for my $name ( %$node ) {
            next if( $name =~ m/^_/ );
            next if( $name eq 'value' );
            my $sub = $node->{ $name };
            my $match = 0;
            if( $rx ) {
                if( $name =~ m/$tagname/ ) {
                    $match = 1;
                }
            }
            elsif( $name eq $tagname ) {
                $match = 1;
            }
            if( $match ) {
                if( ref( $sub ) eq 'ARRAY' ) { push( @$res, @$sub ); }
                else                         { push( @$res, $sub  ); }
            }
            find_by_tagnamer( $sub, $res, $tagname, $rx,  $depth - 1 ) if( $depth );
        }
    }
    if( ref( $node ) eq 'ARRAY' ) {
        for my $item ( @$node ) {
            find_by_tagnamer( $item, $res, $tagname, $rx, $depth );
        }
    }
}

sub find_by_id {
    my ( $node, $id ) = @_;
    my @nodes;
    find_by_idr( $node, \@nodes, $id );
    return \@nodes;
}
sub find_by_idr {
    my ( $node, $res, $id ) = @_;
    if( ref( $node ) eq 'HASH' ) {
        return if( $node->{'_att'} );
        if( $node->{'id'} && $node->{'id'}{'value'} eq $id ) {
            push( @$res, $node );
        }
        for my $name ( keys %$node ) {
            next if( $name =~ m/^_/ );
            next if( $name eq 'value' );
            find_by_idr( $node->{$name}, $res, $id );
        }
    }
    if( ref( $node ) eq 'ARRAY' ) {
        for my $item ( @$node ) {
            find_by_idr( $item, $res, $id );
        }
    }
}

sub find_by_att {
    my ( $node, $att, $val, $depth ) = @_;
    my @nodes;
    $depth ||= 400;
    find_by_attr( $node, \@nodes, $att, $val, $depth );
    return \@nodes;
}
sub find_by_attr {
    my ( $node, $res, $att, $val, $depth ) = @_;
    if( ref( $node ) eq 'HASH' ) {
        return if( $node->{'_att'} );
        if( $val =~ m/^\~(.+)/ ) {
            my $rx = $1;
            if( $node->{$att} ) {
                my $nval = $node->{$att}{'value'};
                if( $nval && $nval =~ m/$rx/ ) {
                    push( @$res, $node );
                }
            }
        }
        elsif( $node->{$att} ) {
            my $nval = $node->{$att}{'value'};
            if( $nval && $nval eq $val ) {
              push( @$res, $node );
            }
        }
        for my $name ( keys %$node ) {
            next if( $name =~ m/^_/ );
            next if( $name eq 'value' );
            find_by_attr( $node->{$name}, $res, $att, $val, $depth-1 ) if( $depth );
        }
    }
    if( ref( $node ) eq 'ARRAY' ) {
        for my $item ( @$node ) {
            find_by_attr( $item, $res, $att, $val, $depth-1  ) if( $depth );
        }
    }
}

# This name is based on the fact that different nodes in a row can be thought of as "mixed" xml
# The parser doesn't retain mixed order, so it sort of "mixes" the ordered xml nodes
# This function gives you a array of the nodes restored to their original order, "unmixing" them.
# A clearer name for this would be "mixed_hash_to_ordered_nodes". That's a lot longer and more boring.
sub unmix {
    my $hash = shift;
    
    my @arr;
    for my $key ( keys %$hash ) {
        next if( $key =~ m/^_/ || $key =~ m/(value|name|comment)/ );
        my $ob = $hash->{ $key };
        if( ref( $ob ) eq 'ARRAY' ) {
            for my $node ( @$ob ) {
                push( @arr, { name => $key, node => $node } );
            }
        }
        else {
            push( @arr, { name => $key, node => $ob } );
        }
    }
    #print Dumper( \@arr );
    my @res = sort { $a->{'node'}{'_pos'} <=> $b->{'node'}{'_pos'} } @arr;
    return \@res;
}


sub simplify {
    my $node = CORE::shift;
    my $ref = ref( $node );
    if( $ref eq 'ARRAY' ) {
        my @ret;
        for my $sub ( @$node ) {
            CORE::push( @ret, simplify( $sub ) );
        }
        return \@ret;
    }
    if( $ref eq 'HASH' ) {
        my %ret;
        my $cnt = 0;
        for my $key ( keys %$node ) {
            next if( $key eq 'comment' || $key eq 'value' || $key =~ m/^_/ );
            $cnt++;
            $ret{ $key } = simplify( $node->{ $key } );
        }
        if( $cnt == 0 ) {
            return $node->{'value'};
        }
        return \%ret;
    }
    return $node;
}

# Do the reverse of the simplify function
sub complicate {
    my $node = shift;
    my $ref = ref( $node );
    if( $ref eq 'HASH' )  {
        for my $key ( keys %$node ) {
            my $replace = complicate( $node->{ $key } );
            #if( $key =~ m/^$att_prefix(.+)/ ) {
            if( $key =~ m/^\_(.+)/ ) {
                my $newkey = $1;
                delete $node->{ $key };
                $replace->{'_att'} = 1;
                $node->{ $newkey } = $replace;
            }
            else {
                $node->{ $key } = $replace if( $replace );
            }
        }
        return 0;
    }
    
    if( $ref eq 'ARRAY' ) {
        my $len = scalar @$node;
        for( my $i=0;$i<$len;$i++ ) {
            my $replace = complicate( $node->[ $i ] );
            $node->[ $i ] = $replace if( $replace );
        }
        return 0;
    }
    
    return { value => $node };
}

1;

__END__