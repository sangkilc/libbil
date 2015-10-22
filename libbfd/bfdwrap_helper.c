/// libBIL top-level interface
/// @file libbfd.idl
/// @author Sang Kil Cha <sangkil.cha\@gmail.com>

/*
Copyright (c) 2014, Sang Kil Cha
All rights reserved.
This software is free software; you can redistribute it and/or
modify it under the terms of the GNU Library General Public
License version 2, with the special exception on linking
described in file LICENSE.

This software is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

#include "bfdwrap.h"

#define PACKAGE
#include <bfd.h>
#include <dis-asm.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include <stdarg.h>
#include <malloc.h>

#include <caml/mlvalues.h>
#include <caml/callback.h>
#include <caml/memory.h>
#include <caml/alloc.h>

#define DEFAULT_TARGET    "i686-pc-linux-gnu"

typedef struct bfd_handle {
    struct bfd*                bfdp;
    struct disassemble_info*   disasp;
    int                        is_from_file;
} bh;

void error_exit( const char* msg )
{
    fprintf( stderr, "%s\n", msg );
    exit( 1 );
}

static
struct bfd* new_bfd_internal( const char* filename,
                              int arch, int machine )
{
    char** matching;
    enum bfd_architecture _arch = (enum bfd_architecture) arch;
    struct bfd* p = bfd_openr( filename, DEFAULT_TARGET );
    const bfd_arch_info_type* info;

    if ( !p ) error_exit( "failure: bfd_openr" );

    if ( _arch == bfd_arch_unknown ) {
        if ( bfd_check_format( p, bfd_archive ) ) {
            // TODO: add archive handling code
            bfd_close_all_done( p );
            error_exit( "currently not supported." );
        }
        if ( bfd_check_format_matches( p, bfd_object, &matching ) ) {
            return p;
        }
        if ( bfd_get_error() == bfd_error_file_ambiguously_recognized ) {
            bfd_close_all_done( p );
            error_exit( "file format is ambiguosly matched" );
        }
        if ( bfd_get_error() != bfd_error_file_not_recognized ) {
            bfd_close_all_done( p );
            error_exit( "file is not recognized" );
        }
        if ( bfd_check_format_matches( p, bfd_core, &matching ) ) {
            return p;
        }
        error_exit( "failed to load the given file" );
        return NULL; /* this will never be called */
    } else {
        info = bfd_lookup_arch( _arch, machine );
        if ( !info ) error_exit( "failed to lookup archicture" );
        bfd_set_arch_info( p, info );
        return p;
    }
}

struct disassemble_info* new_disasm_info( struct bfd* abfd )
{
    struct disassemble_info *di =
      (struct disassemble_info *) malloc( sizeof(struct disassemble_info) );
    if ( !di )
        error_exit( "failed to allocate disassemble_info" );

    init_disassemble_info( di, stdout, (fprintf_ftype) fprintf );

    di->flavour = bfd_get_flavour( abfd );
    di->arch = bfd_get_arch( abfd );
    di->mach = bfd_get_mach( abfd );
    di->octets_per_byte = bfd_octets_per_byte( abfd );
    di->disassembler_needs_relocs = FALSE;

    di->buffer = NULL;
    di->symtab = NULL;

    if ( bfd_big_endian( abfd ) )
        di->display_endian = di->endian = BFD_ENDIAN_BIG;
    else if ( bfd_little_endian ( abfd ) )
        di->display_endian = di->endian = BFD_ENDIAN_LITTLE;

    disassemble_init_for_target( di );

    return di;
}

bh* new_bfd( const char* filename,
             int arch, int machine, int is_from_file )
{
    bh* p = (bh*) malloc( sizeof( bh ) );
    if ( !p ) error_exit( "failure: new_bfd.malloc" );

    p->bfdp = new_bfd_internal( filename, arch, machine );
    p->disasp = new_disasm_info( p->bfdp );
    p->is_from_file = is_from_file;

    return p;
}

bhp new_bfd_from_buf( int arch, int machine )
{
    return new_bfd( "/dev/null", arch, machine, 0 );
}

bhp new_bfd_from_file( const char* filename )
{
    return new_bfd( filename, bfd_arch_unknown, 0, 1 );
}

void delete_bfd( bhp _p )
{
    bh* p = (bh*) _p;

    if ( p->disasp ) {
        free( p->disasp->buffer );
        free( p->disasp );
        p->disasp = NULL;
    }

    if ( bfd_close_all_done( p->bfdp ) == TRUE ) return;
    else error_exit( "failed to close with bfd_close_all_done" );

    free( p );
    p = NULL;
}

void update_disasm_info( bhp _p,
                         char* buffer,
                         int len,
                         unsigned long long addr )
{
    bfd_byte* aux;
    bh* p = (bh*) _p;
    struct disassemble_info* di = p->disasp;

    aux = (bfd_byte*) realloc( di->buffer, len );
    if ( !aux ) error_exit( "update_disasm_info.realloc failed" );
    di->buffer = aux;

    di->buffer_vma = (bfd_vma) addr;
    di->buffer_length = len;
    di->section = NULL;

    if ( !di->buffer )
        error_exit( "failed to allocate disassemble_info.buffer" );
    memcpy( di->buffer, buffer, len );
}

struct bprintf_buffer {
    char *str; // the start of the string
    char *end; // the null terminator at the end of the written string.
    size_t size; // the size of str
};

int bprintf( struct bprintf_buffer *dest, const char *fmt, ... )
{
    va_list ap;
    int ret;
    size_t size_left = dest->size - (dest->end - dest->str);
    va_start(ap, fmt);
    ret = vsnprintf(dest->end, size_left, fmt, ap);
    va_end(ap);
    if ( ret >= size_left ) {
        char *str;

        // we seem to need to call va_start again... is this legal?
        dest->size = dest->size + ret + 1 - size_left;
        str = (char*) realloc( dest->str, dest->size );
        if ( !str ) error_exit( "bprintf.realloc failed" );

        dest->end = str + (dest->end - dest->str);
        dest->str = str;
        size_left = dest->size - (dest->end - dest->str);
        va_start(ap, fmt);
        ret = vsnprintf( dest->end, size_left, fmt, ap );
        va_end(ap);

        assert( ret == size_left-1 && ret > 0 );
    }

    dest->end += ret;
    return ret;
}

char* disasm( bhp _p,
              unsigned long long addr )
{
    static struct bprintf_buffer bits = {NULL, NULL, 0};

    bh* p = (bh*) _p;
    struct disassemble_info* di = p->disasp;
    disassembler_ftype disas = disassembler( p->bfdp );
    fprintf_ftype old_fprintf_func = di->fprintf_func;
    void *oldstream = di->stream;
    di->fprintf_func = (fprintf_ftype) bprintf;
    di->stream = &bits;

    bits.end = bits.str;

    disas( addr, di );

    di->fprintf_func = old_fprintf_func;
    di->stream = oldstream;

    return bits.str;
}

unsigned long long get_entry_point( bhp _p )
{
    bh* p = (bh*) _p;
    return (unsigned long long) p->bfdp->start_address;
}

static int ignore() {
  return 1;
}

int get_instr_length( bhp _p, long long addr )
{
    int len;
    bh* p = (bh*) _p;
    struct disassemble_info* di = p->disasp;
    disassembler_ftype disas = disassembler( p->bfdp );
    fprintf_ftype old_fprintf_func = di->fprintf_func;
    di->fprintf_func = (fprintf_ftype) ignore;
    len = disas( addr, di );
    di->fprintf_func = old_fprintf_func;

    return len;
}

value c2ml_identity( sec_data* input )
{
    return (value) *input;
}

value get_section_data_internal( bhp _p )
{
    CAMLparam0();
    CAMLlocal4( data, v, str, tupl );

    bh* p = (bh*) _p;
    struct bfd* abfd = p->bfdp;
    asection *sect;
    bfd_size_type datasize = 0;

    data = Val_emptylist;

    if ( p->is_from_file ) {

        for ( sect = abfd->sections; sect != NULL; sect = sect->next ) {
            datasize = bfd_get_section_size( sect );
            str = caml_alloc_string( datasize );
            bfd_get_section_contents( abfd, sect,
                                      (bfd_byte*)String_val(str),
                                      0, datasize );
            tupl = caml_alloc_tuple( 3 );
            Store_field( tupl, 0, str );
            Store_field( tupl, 1, caml_copy_int64( sect->vma ) );
            Store_field( tupl, 2, caml_copy_int64( sect->vma + datasize ) );
            v = caml_alloc_small( 2, 0 );
            Field( v, 0 ) = tupl;
            Field( v, 1 ) = data;
            data = v;
        }

    }

    CAMLreturn( data );
}

sec_data get_section_data( bhp _p )
{
    return (sec_data) get_section_data_internal( _p );
}

