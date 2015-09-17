%{
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stddef.h>
#include <string.h>
#include <assert.h>

#include "glsl_parser.h"
#include "glsl_ast.h"
#include "glsl_regen.h"
#include "lex.glsl.h"

void glslerror(const char *s);
int glsllex (void);

int8_t *buffer = NULL;
int8_t *buffer_end = NULL;
int remaining = 0;

struct glsl_node *g_glsl_node_root;

static int8_t *glsl_parse_alloc(size_t size, int align)
{
	int8_t *ret;

	if (size + align > (buffer_end - buffer)) {
		buffer = (int8_t *)malloc(1024*1024);
		buffer_end = buffer + 1024*1024;
	}

	ret = buffer;

	int8_t *trunc = (int8_t *)((~((intptr_t)align - 1)) & ((intptr_t)ret));
	if (trunc != ret) {
		ret = trunc + align;
	}
	buffer = ret + size;
	return ret;
}

static char *glsl_parse_strdup(const char *c)
{
	int len = strlen(c);
	char *ret = (char *)glsl_parse_alloc(len + 1, 1);
	strcpy(ret, c);
	return ret;
}

struct glsl_node *new_glsl_node(int code, ...)
{
	struct glsl_node *temp;
	int i;
	int n = 0;
	va_list vl;
	va_start(vl, code);
	while (1) {
		temp = va_arg(vl, struct glsl_node *);
		if (temp)
			n++;
		else
			break;
	}
	va_end(vl);
	struct glsl_node *g = (struct glsl_node *)glsl_parse_alloc(offsetof(struct glsl_node, children[n]), 8);
	g->code = code;
	g->child_count = n;
	va_start(vl, code);
	for (i = 0; i < n; i++) {
		temp = va_arg(vl, struct glsl_node *);
		g->children[i] = temp;
	}
	va_end(vl);
	return g;
}

struct glsl_node *new_null_glsl_identifier()
{
	struct glsl_node *n = new_glsl_node(IDENTIFIER, NULL);
	n->data.str = NULL;
	return n;
}

%}

%defines

%define api.prefix {glsl}

%define api.value.type union


%type <struct glsl_node *> translation_unit

%type <struct glsl_node *> external_declaration
%type <struct glsl_node *> function_definition
%type <struct glsl_node *> compound_statement_no_new_scope
%type <struct glsl_node *> statement
%type <struct glsl_node *> statement_list
%type <struct glsl_node *> compound_statement
%type <struct glsl_node *> simple_statement
%type <struct glsl_node *> declaration_statement
%type <struct glsl_node *> declaration_tag
%type <struct glsl_node *> declaration_tag_list
%type <struct glsl_node *> end_declaration
%type <struct glsl_node *> declaration
%type <struct glsl_node *> identifier_list
%type <struct glsl_node *> init_declarator_list
%type <struct glsl_node *> single_declaration
%type <struct glsl_node *> initializer
%type <struct glsl_node *> initializer_list

%type <struct glsl_node *> expression_statement
%type <struct glsl_node *> selection_statement
%type <struct glsl_node *> switch_statement
%type <struct glsl_node *> switch_statement_list
%type <struct glsl_node *> case_label
%type <struct glsl_node *> iteration_statement
%type <struct glsl_node *> statement_no_new_scope
%type <struct glsl_node *> for_init_statement
%type <struct glsl_node *> conditionopt

%type <struct glsl_node *> condition
%type <struct glsl_node *> for_rest_statement
%type <struct glsl_node *> jump_statement
%type <struct glsl_node *> function_prototype
%type <struct glsl_node *> function_declarator
%type <struct glsl_node *> parameter_declaration
%type <struct glsl_node *> parameter_declarator
%type <struct glsl_node *> function_header
%type <struct glsl_node *> function_parameter_list
%type <struct glsl_node *> fully_specified_type
%type <struct glsl_node *> parameter_type_specifier

%type <struct glsl_node *> primary_expression
%type <struct glsl_node *> expression
%type <struct glsl_node *> assignment_expression
%type <struct glsl_node *> conditional_expression
%type <struct glsl_node *> logical_or_expression
%type <struct glsl_node *> logical_xor_expression
%type <struct glsl_node *> logical_and_expression
%type <struct glsl_node *> exclusive_or_expression
%type <struct glsl_node *> constant_expression
%type <struct glsl_node *> and_expression
%type <struct glsl_node *> equality_expression
%type <struct glsl_node *> relational_expression
%type <struct glsl_node *> shift_expression
%type <struct glsl_node *> additive_expression
%type <struct glsl_node *> multiplicative_expression
%type <struct glsl_node *> unary_expression
%type <struct glsl_node *> postfix_expression
%type <struct glsl_node *> integer_expression
%type <struct glsl_node *> inclusive_or_expression

%type <struct glsl_node *> function_call
%type <struct glsl_node *> function_call_or_method
%type <struct glsl_node *> function_call_generic
%type <struct glsl_node *> function_call_parameter_list
%type <struct glsl_node *> function_identifier

%type <struct glsl_node *> type_specifier
%type <struct glsl_node *> type_specifier_nonarray
%type <struct glsl_node *> struct_specifier
%type <struct glsl_node *> array_specifier
%type <struct glsl_node *> array_specifier_list

%type <struct glsl_node *> struct_declaration_list
%type <struct glsl_node *> struct_declaration
%type <struct glsl_node *> struct_declarator_list
%type <struct glsl_node *> struct_declarator
%type <struct glsl_node *> type_qualifier
%type <struct glsl_node *> single_type_qualifier
%type <struct glsl_node *> layout_qualifier
%type <struct glsl_node *> layout_qualifier_id_list
%type <struct glsl_node *> layout_qualifier_id

%type <struct glsl_node *> precision_qualifier
%type <struct glsl_node *> invariant_qualifier
%type <struct glsl_node *> precise_qualifier
%type <struct glsl_node *> storage_qualifier
%type <struct glsl_node *> interpolation_qualifier
%type <struct glsl_node *> type_name_list

%type <struct glsl_node *> variable_identifier
%type <struct glsl_node *> decl_identifier
%type <struct glsl_node *> block_identifier
%type <struct glsl_node *> struct_name
%type <struct glsl_node *> type_name
%type <struct glsl_node *> param_name
%type <struct glsl_node *> function_name
%type <struct glsl_node *> field_selection
%type <struct glsl_node *> declaration_tag_identifier
%type <struct glsl_node *> type_specifier_identifier
%type <struct glsl_node *> layout_identifier

%type <int> assignment_operator
%type <int> unary_operator

%token CONST
%token BOOL
%token FLOAT
%token DOUBLE
%token INT
%token UINT
%token BREAK
%token CONTINUE
%token DO
%token ELSE
%token FOR
%token IF
%token DISCARD
%token RETURN
%token RETURN_VALUE
%token SWITCH
%token CASE
%token DEFAULT
%token SUBROUTINE
%token BVEC2
%token BVEC3
%token BVEC4
%token IVEC2
%token IVEC3
%token IVEC4
%token UVEC2
%token UVEC3
%token UVEC4
%token VEC2
%token VEC3
%token VEC4
%token MAT2
%token MAT3
%token MAT4
%token CENTROID
%token IN
%token OUT
%token INOUT
%token UNIFORM
%token PATCH
%token SAMPLE
%token BUFFER
%token SHARED
%token COHERENT
%token VOLATILE
%token RESTRICT
%token READONLY
%token WRITEONLY
%token DVEC2
%token DVEC3
%token DVEC4
%token DMAT2
%token DMAT3
%token DMAT4
%token NOPERSPECTIVE
%token FLAT
%token SMOOTH
%token LAYOUT
%token MAT2X2
%token MAT2X3
%token MAT2X4
%token MAT3X2
%token MAT3X3
%token MAT3X4
%token MAT4X2
%token MAT4X3
%token MAT4X4
%token DMAT2X2
%token DMAT2X3
%token DMAT2X4
%token DMAT3X2
%token DMAT3X3
%token DMAT3X4
%token DMAT4X2
%token DMAT4X3
%token DMAT4X4
%token ATOMIC_UINT
%token SAMPLER1D
%token SAMPLER2D
%token SAMPLER3D
%token SAMPLERCUBE
%token SAMPLER1DSHADOW
%token SAMPLER2DSHADOW
%token SAMPLERCUBESHADOW
%token SAMPLER1DARRAY
%token SAMPLER2DARRAY
%token SAMPLER1DARRAYSHADOW
%token SAMPLER2DARRAYSHADOW
%token ISAMPLER1D
%token ISAMPLER2D
%token ISAMPLER3D
%token ISAMPLERCUBE
%token ISAMPLER1DARRAY
%token ISAMPLER2DARRAY
%token USAMPLER1D
%token USAMPLER2D
%token USAMPLER3D
%token USAMPLERCUBE
%token USAMPLER1DARRAY
%token USAMPLER2DARRAY
%token SAMPLER2DRECT
%token SAMPLER2DRECTSHADOW
%token ISAMPLER2DRECT
%token USAMPLER2DRECT
%token SAMPLERBUFFER
%token ISAMPLERBUFFER
%token USAMPLERBUFFER
%token SAMPLERCUBEARRAY
%token SAMPLERCUBEARRAYSHADOW
%token ISAMPLERCUBEARRAY
%token USAMPLERCUBEARRAY
%token SAMPLER2DMS
%token ISAMPLER2DMS
%token USAMPLER2DMS
%token SAMPLER2DMSARRAY
%token ISAMPLER2DMSARRAY
%token USAMPLER2DMSARRAY
%token IMAGE1D
%token IIMAGE1D
%token UIMAGE1D
%token IMAGE2D
%token IIMAGE2D
%token UIMAGE2D
%token IMAGE3D
%token IIMAGE3D
%token UIMAGE3D
%token IMAGE2DRECT
%token IIMAGE2DRECT
%token UIMAGE2DRECT
%token IMAGECUBE
%token IIMAGECUBE
%token UIMAGECUBE
%token IMAGEBUFFER
%token IIMAGEBUFFER
%token UIMAGEBUFFER
%token IMAGE1DARRAY
%token IIMAGE1DARRAY
%token UIMAGE1DARRAY
%token IMAGE2DARRAY
%token IIMAGE2DARRAY
%token UIMAGE2DARRAY
%token IMAGECUBEARRAY
%token IIMAGECUBEARRAY
%token UIMAGECUBEARRAY
%token IMAGE2DMS
%token IIMAGE2DMS
%token UIMAGE2DMS
%token IMAGE2DMSARRAY
%token IIMAGE2DMSARRAY
%token UIMAGE2DMSARRAY
%token STRUCT
%token VOID
%token WHILE
%token <char *> IDENTIFIER
%token <float> FLOATCONSTANT
%token <double> DOUBLECONSTANT
%token <int> INTCONSTANT
%token <unsigned int> UINTCONSTANT
%token TRUE
%token FALSE
%token LEFT_OP
%token RIGHT_OP
%token INC_OP
%token DEC_OP
%token LE_OP
%token GE_OP
%token EQ_OP
%token NE_OP
%token AND_OP
%token OR_OP
%token XOR_OP
%token MUL_ASSIGN
%token DIV_ASSIGN
%token ADD_ASSIGN
%token MOD_ASSIGN
%token LEFT_ASSIGN
%token RIGHT_ASSIGN
%token AND_ASSIGN
%token XOR_ASSIGN
%token OR_ASSIGN
%token SUB_ASSIGN
%token LEFT_PAREN
%token RIGHT_PAREN
%token LEFT_BRACKET
%token RIGHT_BRACKET
%token LEFT_BRACE
%token RIGHT_BRACE
%token DOT
%token COMMA
%token COLON
%token EQUAL
%token SEMICOLON
%token BANG
%token DASH
%token TILDE
%token PLUS
%token STAR
%token SLASH
%token PERCENT
%token LEFT_ANGLE
%token RIGHT_ANGLE
%token VERTICAL_BAR
%token CARET
%token AMPERSAND
%token QUESTION
%token INVARIANT
%token PRECISE
%token HIGHP
%token MEDIUMP
%token LOWP
%token PRECISION
%token AT

%token UNARY_PLUS
%token UNARY_DASH
%token PRE_INC_OP
%token PRE_DEC_OP
%token POST_DEC_OP
%token POST_INC_OP
%token ARRAY_REF_OP
%token FUNCTION_CALL
%token TYPE_NAME_LIST
%token TYPE_SPECIFIER
%token POSTFIX_EXPRESSION
%token TYPE_QUALIFIER_LIST
%token STRUCT_DECLARATION
%token STRUCT_DECLARATOR
%token STRUCT_SPECIFIER
%token FUNCTION_DEFINITION
%token DECLARATION
%token STATEMENT_LIST
%token TRANSLATION_UNIT
%token DECLARATION_TAG
%token DECLARATION_TAG_LIST
%token END_DECLARATION
%token PRECISION_DECLARATION
%token BLOCK_DECLARATION
%token TYPE_QUALIFIER_DECLARATION
%token IDENTIFIER_LIST
%token INIT_DECLARATOR_LIST
%token FULLY_SPECIFIED_TYPE
%token SINGLE_DECLARATION
%token SINGLE_INIT_DECLARATION
%token INITIALIZER_LIST
%token EXPRESSION_STATEMENT
%token SELECTION_STATEMENT
%token SELECTION_STATEMENT_ELSE
%token SWITCH_STATEMENT
%token FOR_REST_STATEMENT
%token WHILE_STATEMENT
%token DO_STATEMENT
%token FOR_STATEMENT
%token CASE_LABEL
%token CONDITION_OPT
%token ASSIGNMENT_CONDITION
%token EXPRESSION_CONDITION
%token FUNCTION_HEADER
%token FUNCTION_DECLARATION
%token FUNCTION_PARAMETER_LIST
%token PARAMETER_DECLARATION
%token PARAMETER_DECLARATOR
%token UNINITIALIZED_DECLARATION
%token ARRAY_SPECIFIER
%token ARRAY_SPECIFIER_LIST
%token STRUCT_DECLARATOR_LIST
%token FUNCTION_CALL_PARAMETER_LIST
%token STRUCT_DECLARATION_LIST
%token LAYOUT_QUALIFIER_ID
%token LAYOUT_QUALIFIER_ID_LIST
%token SUBROUTINE_TYPE
%token PAREN_EXPRESSION

%token NUM_TOKEN
%%

root			: translation_unit { g_glsl_node_root = $1; }

translation_unit	: external_declaration { $$ = $1; }
			| translation_unit external_declaration { $$ = new_glsl_node(TRANSLATION_UNIT, $1, $2, NULL); }
			;

block_identifier	: IDENTIFIER { $$ = new_glsl_node(IDENTIFIER, NULL); $$->data.str = glsl_parse_strdup($1); }
			;

decl_identifier		: IDENTIFIER { $$ = new_glsl_node(IDENTIFIER, NULL); $$->data.str = glsl_parse_strdup($1); }
			;

struct_name		: IDENTIFIER { $$ = new_glsl_node(IDENTIFIER, NULL); $$->data.str = glsl_parse_strdup($1); }
			;

type_name		: IDENTIFIER { $$ = new_glsl_node(IDENTIFIER, NULL); $$->data.str = glsl_parse_strdup($1); }
			;

param_name		: IDENTIFIER { $$ = new_glsl_node(IDENTIFIER, NULL); $$->data.str = glsl_parse_strdup($1); }
			;

function_name		: IDENTIFIER { $$ = new_glsl_node(IDENTIFIER, NULL); $$->data.str = glsl_parse_strdup($1); }
			;

field_selection		: IDENTIFIER { $$ = new_glsl_node(IDENTIFIER, NULL); $$->data.str = glsl_parse_strdup($1); }
			;

variable_identifier	: IDENTIFIER { $$ = new_glsl_node(IDENTIFIER, NULL); $$->data.str = glsl_parse_strdup($1); }
			;

layout_identifier	: IDENTIFIER { $$ = new_glsl_node(IDENTIFIER, NULL); $$->data.str = glsl_parse_strdup($1); }
			;

declaration_tag_identifier : IDENTIFIER { $$ = new_glsl_node(IDENTIFIER, NULL); $$->data.str = glsl_parse_strdup($1); }
			;

type_specifier_identifier : IDENTIFIER { $$ = new_glsl_node(IDENTIFIER, NULL); $$->data.str = glsl_parse_strdup($1); }
			;

external_declaration	: function_definition { $$ = $1; }
			| declaration { $$ = $1; }
			;

function_definition	: function_prototype compound_statement_no_new_scope { $$ = new_glsl_node(FUNCTION_DEFINITION, $1, $2, NULL); }
			| function_prototype { $$ = new_glsl_node(FUNCTION_DEFINITION,$1, new_glsl_node(STATEMENT_LIST, NULL), NULL); }
			;

compound_statement_no_new_scope : LEFT_BRACE RIGHT_BRACE { $$ = new_glsl_node(STATEMENT_LIST, NULL); }
			| LEFT_BRACE statement_list RIGHT_BRACE { $$ = $2; }
			;

statement		: compound_statement { $$ = $1; }
			| simple_statement { $$ = $1; }
			;

statement_list		: statement { $$ = new_glsl_node(STATEMENT_LIST, $1, NULL); }
			| statement_list statement { $$ = new_glsl_node(STATEMENT_LIST, $1, $2, NULL); }
			;

compound_statement	: LEFT_BRACE RIGHT_BRACE { $$ = new_glsl_node(STATEMENT_LIST, NULL); }
			| LEFT_BRACE statement_list RIGHT_BRACE { $$ = $2; }
			;

simple_statement	: declaration_statement { $$ = $1; }
			| expression_statement { $$ = $1; }
			| selection_statement { $$ = $1; }
			| switch_statement { $$ = $1; }
			| case_label { $$= $1; }
			| iteration_statement { $$ = $1; }
			| jump_statement { $$ = $1; }
			;

declaration_statement	: declaration { $$ = $1; }
			;

declaration_tag		: declaration_tag_identifier { $$ = new_glsl_node(DECLARATION_TAG, $1, NULL); }
			| declaration_tag_identifier EQUAL primary_expression { $$ = new_glsl_node(DECLARATION_TAG, $1, $3, NULL); }
			;

declaration_tag_list	: declaration_tag { $$ = $1; }
			| declaration_tag_list COMMA declaration_tag { $$ = new_glsl_node(DECLARATION_TAG_LIST, $1, $3, NULL); }
			;

end_declaration		: AT declaration_tag_list AT SEMICOLON { $$ = new_glsl_node(END_DECLARATION, $2, NULL); }
			| SEMICOLON { $$ = new_glsl_node(END_DECLARATION, NULL); }
			;

declaration		: function_prototype SEMICOLON { $$ = $1; }
			| init_declarator_list end_declaration { $$ = $1; }
			| PRECISION precision_qualifier type_specifier SEMICOLON { $$ = new_glsl_node(PRECISION_DECLARATION, $2, $3, NULL); }
			| type_qualifier block_identifier LEFT_BRACE struct_declaration_list RIGHT_BRACE SEMICOLON { $$ = new_glsl_node(BLOCK_DECLARATION, $1, $2, $4, new_null_glsl_identifier(), new_glsl_node(ARRAY_SPECIFIER_LIST, NULL), NULL);}
			| type_qualifier block_identifier LEFT_BRACE struct_declaration_list RIGHT_BRACE decl_identifier SEMICOLON { $$ = new_glsl_node(BLOCK_DECLARATION, $1, $2, $4, $6, new_glsl_node(ARRAY_SPECIFIER_LIST, NULL), NULL);}
			| type_qualifier block_identifier LEFT_BRACE struct_declaration_list RIGHT_BRACE decl_identifier array_specifier_list SEMICOLON { $$ = new_glsl_node(BLOCK_DECLARATION, $1, $2, $4, $6, $7, NULL);}
			| type_qualifier SEMICOLON { $$ = new_glsl_node(UNINITIALIZED_DECLARATION, $1, NULL); }
			| type_qualifier type_name SEMICOLON { $$ = new_glsl_node(UNINITIALIZED_DECLARATION, $1, $2, NULL); }
			| type_qualifier type_name identifier_list SEMICOLON { $$ = new_glsl_node(UNINITIALIZED_DECLARATION, $1, $2, $3, NULL); }
			;

identifier_list		: COMMA decl_identifier { $$ = $2; }
			| identifier_list COMMA decl_identifier { $$ = new_glsl_node(IDENTIFIER_LIST, $1, $3, NULL); }
			;

init_declarator_list	: single_declaration { $$ = $1; }
			| init_declarator_list COMMA decl_identifier { $$ = new_glsl_node(INIT_DECLARATOR_LIST, $1, $3, NULL); }
			| init_declarator_list COMMA decl_identifier array_specifier_list { $$ = new_glsl_node(INIT_DECLARATOR_LIST, $1, $3, $4, NULL); }
			| init_declarator_list COMMA decl_identifier array_specifier_list EQUAL initializer { $$ = new_glsl_node(INIT_DECLARATOR_LIST, $1, $3, $4, $6, NULL); }
			| init_declarator_list COMMA decl_identifier EQUAL initializer { $$ = new_glsl_node(INIT_DECLARATOR_LIST, $1, $3, new_glsl_node(ARRAY_SPECIFIER_LIST, NULL), $5, NULL); }
			;

single_declaration	: fully_specified_type { $$ = new_glsl_node(SINGLE_DECLARATION, $1, new_null_glsl_identifier(), new_glsl_node(ARRAY_SPECIFIER_LIST, NULL), NULL); }
			| fully_specified_type decl_identifier { $$ = new_glsl_node(SINGLE_DECLARATION, $1, $2, new_glsl_node(ARRAY_SPECIFIER_LIST, NULL), NULL); }
			| fully_specified_type decl_identifier array_specifier_list { $$ = new_glsl_node(SINGLE_DECLARATION, $1, $2, $3, NULL); }
			| fully_specified_type decl_identifier array_specifier_list EQUAL initializer { $$ = new_glsl_node(SINGLE_INIT_DECLARATION, $1, $2, $3, $5, NULL); }
			| fully_specified_type decl_identifier EQUAL initializer { $$ = new_glsl_node(SINGLE_INIT_DECLARATION, $1, $2,  new_glsl_node(ARRAY_SPECIFIER_LIST, NULL), $4, NULL); }
			;

initializer		: assignment_expression { $$ = $1; }
			| LEFT_BRACE initializer_list RIGHT_BRACE { $$ = $2; }
			| LEFT_BRACE initializer_list COMMA RIGHT_BRACE { $$ = $2; }
			;

initializer_list	: initializer { $$ = $1; }
			| initializer_list COMMA initializer { $$ = new_glsl_node(INITIALIZER_LIST, $1, $3, NULL); }
			;

expression_statement	: SEMICOLON { $$ = new_glsl_node(EXPRESSION_STATEMENT, NULL); }
			| expression SEMICOLON { $$ = new_glsl_node(EXPRESSION_STATEMENT, $1, NULL); }
			;

selection_statement	: IF LEFT_PAREN expression RIGHT_PAREN statement { $$ = new_glsl_node(SELECTION_STATEMENT, $3, $5, NULL); }
			| IF LEFT_PAREN expression RIGHT_PAREN statement ELSE statement { $$ = new_glsl_node(SELECTION_STATEMENT_ELSE, $3, $5, $7, NULL); }
			;

switch_statement	: SWITCH LEFT_PAREN expression RIGHT_PAREN LEFT_BRACE switch_statement_list RIGHT_BRACE { $$ = new_glsl_node(SWITCH_STATEMENT, $3, $6, NULL); }
			;

switch_statement_list	: { $$ = new_glsl_node(STATEMENT_LIST, NULL); }
			| statement_list { $$ = $1; }
			;

case_label		: CASE expression COLON { $$ = new_glsl_node(CASE_LABEL, $2, NULL); }
			| DEFAULT COLON { $$ = new_glsl_node(CASE_LABEL, NULL); }
			;

iteration_statement	: WHILE LEFT_PAREN condition RIGHT_PAREN statement_no_new_scope { $$ = new_glsl_node(WHILE_STATEMENT, $3, $5, NULL); }
			| DO statement WHILE LEFT_PAREN expression RIGHT_PAREN SEMICOLON { $$ = new_glsl_node(DO_STATEMENT, $2, $5, NULL); }
			| FOR LEFT_PAREN for_init_statement for_rest_statement RIGHT_PAREN statement_no_new_scope { $$ = new_glsl_node(FOR_STATEMENT, $3, $4, $6, NULL); }
			;

statement_no_new_scope	: compound_statement_no_new_scope { $$ = $1; }
			| simple_statement { $$ = $1; }
			;

for_init_statement	: expression_statement { $$ = $1; }
			| declaration_statement { $$ = $1; }
			;

conditionopt		: condition { $$ = new_glsl_node(CONDITION_OPT, $1, NULL); }
			| { $$ = new_glsl_node(CONDITION_OPT, NULL); }
			;

condition		: expression { $$ = new_glsl_node(EXPRESSION_CONDITION, $1, NULL); }
			| fully_specified_type variable_identifier EQUAL initializer { $$ = new_glsl_node(ASSIGNMENT_CONDITION, $1, $2, $4, NULL); }
			;

for_rest_statement	: conditionopt SEMICOLON { $$ = new_glsl_node(FOR_REST_STATEMENT, $1, NULL); }
			| conditionopt SEMICOLON expression { $$ = new_glsl_node(FOR_REST_STATEMENT, $1, $3, NULL); }
			;

jump_statement		: CONTINUE SEMICOLON { $$ = new_glsl_node(CONTINUE, NULL); }
			| BREAK SEMICOLON { $$ = new_glsl_node(BREAK, NULL); }
			| RETURN SEMICOLON { $$ = new_glsl_node(RETURN, NULL); }
			| RETURN expression SEMICOLON { $$ = new_glsl_node(RETURN_VALUE, $2, NULL); }
			| DISCARD SEMICOLON { $$ = new_glsl_node(DISCARD, NULL); }
			;

function_prototype	: function_declarator RIGHT_PAREN { $$ = $1; }
			;

function_declarator	: function_header { $$ = new_glsl_node(FUNCTION_DECLARATION, $1, new_glsl_node(FUNCTION_PARAMETER_LIST, NULL), NULL); }
			| function_header function_parameter_list { $$ = new_glsl_node(FUNCTION_DECLARATION, $1, $2, NULL); }
			;

function_parameter_list : parameter_declaration { $$ = new_glsl_node(FUNCTION_PARAMETER_LIST, $1, NULL); }
			| function_parameter_list COMMA parameter_declaration { $$ = new_glsl_node(FUNCTION_PARAMETER_LIST, $1, $3, NULL); }
			;

parameter_declaration	: type_qualifier parameter_declarator { $$ = new_glsl_node(PARAMETER_DECLARATION, $1, $2, NULL); }
			| parameter_declarator { $$ = new_glsl_node(PARAMETER_DECLARATION, new_glsl_node(TYPE_QUALIFIER_LIST, NULL), $1, NULL); }
			| type_qualifier parameter_type_specifier { $$ = new_glsl_node(PARAMETER_DECLARATION, $1, $2, NULL); }
			| parameter_type_specifier { $$ = new_glsl_node(PARAMETER_DECLARATION, new_glsl_node(TYPE_QUALIFIER_LIST, NULL), $1, NULL); }
			;

parameter_declarator	: type_specifier param_name { $$ = new_glsl_node(PARAMETER_DECLARATOR, $1, $2, NULL); }
			| type_specifier param_name array_specifier_list { $$ = new_glsl_node(PARAMETER_DECLARATOR, $1, $2, $3, NULL);}
			;

function_header		: fully_specified_type function_name LEFT_PAREN { $$ = new_glsl_node(FUNCTION_HEADER, $1, $2, NULL); }
			;

fully_specified_type	: type_specifier { $$ = new_glsl_node(FULLY_SPECIFIED_TYPE, new_glsl_node(TYPE_QUALIFIER_LIST, NULL), $1, NULL); }
			| type_qualifier type_specifier { $$ = new_glsl_node(FULLY_SPECIFIED_TYPE, $1, $2, NULL); }
			;

parameter_type_specifier : type_specifier { $$ = new_glsl_node(PARAMETER_DECLARATOR, $1, NULL); }
			;

type_specifier		: type_specifier_nonarray { $$ = new_glsl_node(TYPE_SPECIFIER, $1, new_glsl_node(ARRAY_SPECIFIER_LIST, NULL), NULL); }
			| type_specifier_nonarray array_specifier_list { $$ = new_glsl_node(TYPE_SPECIFIER, $1, $2, NULL); }
			;

array_specifier_list	: array_specifier { $$ = new_glsl_node(ARRAY_SPECIFIER_LIST, $1, NULL); }
		     	| array_specifier_list array_specifier { $$ = new_glsl_node(ARRAY_SPECIFIER_LIST, $1, $2, NULL); }
			;

array_specifier		: LEFT_BRACKET RIGHT_BRACKET { $$ = new_glsl_node(ARRAY_SPECIFIER, NULL); }
			| LEFT_BRACKET constant_expression RIGHT_BRACKET { $$ = new_glsl_node(ARRAY_SPECIFIER, $2, NULL); }
			;

type_specifier_nonarray : VOID { $$ = new_glsl_node(VOID, NULL); }
			| FLOAT { $$ = new_glsl_node(FLOAT, NULL); }
			| DOUBLE { $$ = new_glsl_node(DOUBLE, NULL); }
			| INT { $$ = new_glsl_node(INT, NULL); }
			| UINT { $$ = new_glsl_node(UINT, NULL); }
			| BOOL { $$ = new_glsl_node(BOOL, NULL); }
			| VEC2 { $$ = new_glsl_node(VEC2, NULL); }
			| VEC3 { $$ = new_glsl_node(VEC3, NULL); }
			| VEC4 { $$ = new_glsl_node(VEC4, NULL); }
			| DVEC2 { $$ = new_glsl_node(DVEC2, NULL); }
			| DVEC3 { $$ = new_glsl_node(DVEC3, NULL); }
			| DVEC4 { $$ = new_glsl_node(DVEC4, NULL); }
			| BVEC2 { $$ = new_glsl_node(BVEC2, NULL); }
			| BVEC3 { $$ = new_glsl_node(BVEC3, NULL); }
			| BVEC4 { $$ = new_glsl_node(BVEC4, NULL); }
			| IVEC2 { $$ = new_glsl_node(IVEC2, NULL); }
			| IVEC3 { $$ = new_glsl_node(IVEC3, NULL); }
			| IVEC4 { $$ = new_glsl_node(IVEC4, NULL); }
			| UVEC2 { $$ = new_glsl_node(UVEC2, NULL); }
			| UVEC3 { $$ = new_glsl_node(UVEC3, NULL); }
			| UVEC4 { $$ = new_glsl_node(UVEC4, NULL); }
			| MAT2 { $$ = new_glsl_node(MAT2, NULL); }
			| MAT3 { $$ = new_glsl_node(MAT3, NULL); }
			| MAT4 { $$ = new_glsl_node(MAT4, NULL); }
			| MAT2X2 { $$ = new_glsl_node(MAT2X2, NULL); }
			| MAT2X3 { $$ = new_glsl_node(MAT2X3, NULL); }
			| MAT2X4 { $$ = new_glsl_node(MAT2X4, NULL); }
			| MAT3X2 { $$ = new_glsl_node(MAT3X2, NULL); }
			| MAT3X3 { $$ = new_glsl_node(MAT3X3, NULL); }
			| MAT3X4 { $$ = new_glsl_node(MAT3X4, NULL); }
			| MAT4X2 { $$ = new_glsl_node(MAT4X2, NULL); }
			| MAT4X3 { $$ = new_glsl_node(MAT4X3, NULL); }
			| MAT4X4 { $$ = new_glsl_node(MAT4X4, NULL); }
			| DMAT2 { $$ = new_glsl_node(DMAT2, NULL); }
			| DMAT3 { $$ = new_glsl_node(DMAT3, NULL); }
			| DMAT4 { $$ = new_glsl_node(DMAT4, NULL); }
			| DMAT2X2 { $$ = new_glsl_node(DMAT2X2, NULL); }
			| DMAT2X3 { $$ = new_glsl_node(DMAT2X3, NULL); }
			| DMAT2X4 { $$ = new_glsl_node(DMAT2X4, NULL); }
			| DMAT3X2 { $$ = new_glsl_node(DMAT3X2, NULL); }
			| DMAT3X3 { $$ = new_glsl_node(DMAT3X3, NULL); }
			| DMAT3X4 { $$ = new_glsl_node(DMAT3X4, NULL); }
			| DMAT4X2 { $$ = new_glsl_node(DMAT4X2, NULL); }
			| DMAT4X3 { $$ = new_glsl_node(DMAT4X3, NULL); }
			| DMAT4X4 { $$ = new_glsl_node(DMAT4X4, NULL); }
			| ATOMIC_UINT { $$ = new_glsl_node(UINT, NULL); }
			| SAMPLER1D { $$ = new_glsl_node(SAMPLER1D, NULL); }
			| SAMPLER2D { $$ = new_glsl_node(SAMPLER2D, NULL); }
			| SAMPLER3D { $$ = new_glsl_node(SAMPLER3D, NULL); }
			| SAMPLERCUBE { $$ = new_glsl_node(SAMPLERCUBE, NULL); }
			| SAMPLER1DSHADOW { $$ = new_glsl_node(SAMPLER1DSHADOW, NULL); }
			| SAMPLER2DSHADOW { $$ = new_glsl_node(SAMPLER2DSHADOW, NULL); }
			| SAMPLERCUBESHADOW { $$ = new_glsl_node(SAMPLERCUBESHADOW, NULL); }
			| SAMPLER1DARRAY { $$ = new_glsl_node(SAMPLER1DARRAY, NULL); }
			| SAMPLER2DARRAY { $$ = new_glsl_node(SAMPLER2DARRAY, NULL); }
			| SAMPLER1DARRAYSHADOW { $$ = new_glsl_node(SAMPLER1DARRAYSHADOW, NULL); }
			| SAMPLER2DARRAYSHADOW { $$ = new_glsl_node(SAMPLER2DARRAYSHADOW, NULL); }
			| SAMPLERCUBEARRAY { $$ = new_glsl_node(SAMPLERCUBEARRAY, NULL); }
			| SAMPLERCUBEARRAYSHADOW { $$ = new_glsl_node(SAMPLERCUBEARRAYSHADOW, NULL); }
			| ISAMPLER1D { $$ = new_glsl_node(ISAMPLER1D, NULL); }
			| ISAMPLER2D { $$ = new_glsl_node(ISAMPLER2D, NULL); }
			| ISAMPLER3D { $$ = new_glsl_node(ISAMPLER3D, NULL); }
			| ISAMPLERCUBE { $$ = new_glsl_node(ISAMPLERCUBE, NULL); }
			| ISAMPLER1DARRAY { $$ = new_glsl_node(ISAMPLER1DARRAY, NULL); }
			| ISAMPLER2DARRAY { $$ = new_glsl_node(ISAMPLER2DARRAY, NULL); }
			| ISAMPLERCUBEARRAY { $$ = new_glsl_node(ISAMPLERCUBEARRAY, NULL); }
			| USAMPLER1D { $$ = new_glsl_node(USAMPLER1D, NULL); }
			| USAMPLER2D { $$ = new_glsl_node(USAMPLER2D, NULL); }
			| USAMPLER3D { $$ = new_glsl_node(USAMPLER3D, NULL); }
			| USAMPLERCUBE { $$ = new_glsl_node(USAMPLERCUBE, NULL); }
			| USAMPLER1DARRAY { $$ = new_glsl_node(USAMPLER1DARRAY, NULL); }
			| USAMPLER2DARRAY { $$ = new_glsl_node(USAMPLER2DARRAY, NULL); }
			| USAMPLERCUBEARRAY { $$ = new_glsl_node(USAMPLERCUBEARRAY, NULL); }
			| SAMPLER2DRECT { $$ = new_glsl_node(SAMPLER2DRECT, NULL); }
			| SAMPLER2DRECTSHADOW { $$ = new_glsl_node(SAMPLER2DRECTSHADOW, NULL); }
			| ISAMPLER2DRECT { $$ = new_glsl_node(ISAMPLER2DRECT, NULL); }
			| USAMPLER2DRECT { $$ = new_glsl_node(USAMPLER2DRECT, NULL); }
			| SAMPLERBUFFER { $$ = new_glsl_node(SAMPLERBUFFER, NULL); }
			| ISAMPLERBUFFER { $$ = new_glsl_node(ISAMPLERBUFFER, NULL); }
			| USAMPLERBUFFER { $$ = new_glsl_node(USAMPLERBUFFER, NULL); }
			| SAMPLER2DMS { $$ = new_glsl_node(SAMPLER2DMS, NULL); }
			| ISAMPLER2DMS { $$ = new_glsl_node(ISAMPLER2DMS, NULL); }
			| USAMPLER2DMS { $$ = new_glsl_node(USAMPLER2DMS, NULL); }
			| SAMPLER2DMSARRAY { $$ = new_glsl_node(SAMPLER2DMSARRAY, NULL); }
			| ISAMPLER2DMSARRAY { $$ = new_glsl_node(ISAMPLER2DMSARRAY, NULL); }
			| USAMPLER2DMSARRAY { $$ = new_glsl_node(USAMPLER2DMSARRAY, NULL); }
			| IMAGE1D { $$ = new_glsl_node(IMAGE1D, NULL); }
			| IIMAGE1D { $$ = new_glsl_node(IIMAGE1D, NULL); }
			| UIMAGE1D { $$ = new_glsl_node(UIMAGE1D, NULL); }
			| IMAGE2D { $$ = new_glsl_node(IMAGE2D, NULL); }
			| IIMAGE2D { $$ = new_glsl_node(IIMAGE2D, NULL); }
			| UIMAGE2D { $$ = new_glsl_node(UIMAGE2D, NULL); }
			| IMAGE3D { $$ = new_glsl_node(IMAGE3D, NULL); }
			| IIMAGE3D { $$ = new_glsl_node(IIMAGE3D, NULL); }
			| UIMAGE3D { $$ = new_glsl_node(UIMAGE3D, NULL); }
			| IMAGE2DRECT { $$ = new_glsl_node(IMAGE2DRECT, NULL); }
			| IIMAGE2DRECT { $$ = new_glsl_node(IIMAGE2DRECT, NULL); }
			| UIMAGE2DRECT { $$ = new_glsl_node(UIMAGE2DRECT, NULL); }
			| IMAGECUBE { $$ = new_glsl_node(IMAGECUBE, NULL); }
			| IIMAGECUBE { $$ = new_glsl_node(IIMAGECUBE, NULL); }
			| UIMAGECUBE { $$ = new_glsl_node(UIMAGECUBE, NULL); }
			| IMAGEBUFFER { $$ = new_glsl_node(IMAGEBUFFER, NULL); }
			| IIMAGEBUFFER { $$ = new_glsl_node(IIMAGEBUFFER, NULL); }
			| UIMAGEBUFFER { $$ = new_glsl_node(UIMAGEBUFFER, NULL); }
			| IMAGE1DARRAY { $$ = new_glsl_node(IMAGE1DARRAY, NULL); }
			| IIMAGE1DARRAY { $$ = new_glsl_node(IIMAGE1DARRAY, NULL); }
			| UIMAGE1DARRAY { $$ = new_glsl_node(UIMAGE1DARRAY, NULL); }
			| IMAGE2DARRAY { $$ = new_glsl_node(IMAGE2DARRAY, NULL); }
			| IIMAGE2DARRAY { $$ = new_glsl_node(IIMAGE2DARRAY, NULL); }
			| UIMAGE2DARRAY { $$ = new_glsl_node(UIMAGE2DARRAY, NULL); }
			| IMAGECUBEARRAY { $$ = new_glsl_node(IMAGECUBEARRAY, NULL); }
			| IIMAGECUBEARRAY { $$ = new_glsl_node(IIMAGECUBEARRAY, NULL); }
			| UIMAGECUBEARRAY { $$ = new_glsl_node(UIMAGECUBEARRAY, NULL); }
			| IMAGE2DMS { $$ = new_glsl_node(IMAGE2DMS, NULL); }
			| IIMAGE2DMS { $$ = new_glsl_node(IIMAGE2DMS, NULL); }
			| UIMAGE2DMS { $$ = new_glsl_node(UIMAGE2DMS, NULL); }
			| IMAGE2DMSARRAY { $$ = new_glsl_node(IMAGE2DMSARRAY, NULL); }
			| IIMAGE2DMSARRAY { $$ = new_glsl_node(IIMAGE2DMSARRAY, NULL); }
			| UIMAGE2DMSARRAY { $$ = new_glsl_node(UIMAGE2DMSARRAY, NULL); }
			| struct_specifier { $$ = $1; }
			| type_specifier_identifier { $$ = $1; }
			;

struct_specifier	: STRUCT struct_name LEFT_BRACE struct_declaration_list RIGHT_BRACE { $$ = new_glsl_node(STRUCT_SPECIFIER, $2, $4, NULL);}
			| STRUCT LEFT_BRACE struct_declaration_list RIGHT_BRACE { $$ = new_glsl_node(STRUCT_SPECIFIER, new_null_glsl_identifier(), $3, NULL); }
			;

struct_declaration_list : struct_declaration { $$ = new_glsl_node(STRUCT_DECLARATION_LIST, $1, NULL); }
			| struct_declaration_list struct_declaration { $$ = new_glsl_node(STRUCT_DECLARATION_LIST, $1, $2, NULL); }
			;

struct_declaration	: type_specifier struct_declarator_list SEMICOLON { $$ = new_glsl_node(STRUCT_DECLARATION, new_glsl_node(TYPE_QUALIFIER_LIST, NULL), $1, $2, NULL); }
			| type_qualifier type_specifier struct_declarator_list SEMICOLON { $$ = new_glsl_node(STRUCT_DECLARATION, $1, $2, $3, NULL); }
			;

struct_declarator_list	: struct_declarator { $$ = new_glsl_node(STRUCT_DECLARATOR_LIST, $1, NULL); }
			| struct_declarator_list COMMA struct_declarator { $$ = new_glsl_node(STRUCT_DECLARATOR_LIST, $1, $3, NULL); }
			;

struct_declarator	: decl_identifier { $$ = new_glsl_node(STRUCT_DECLARATOR, $1, NULL); }
			| decl_identifier array_specifier_list { $$ = new_glsl_node(STRUCT_DECLARATOR, $1, $2, NULL); }
			;

type_qualifier		: single_type_qualifier { $$ = new_glsl_node(TYPE_QUALIFIER_LIST, $1, NULL); }
			| type_qualifier single_type_qualifier { $$ = new_glsl_node(TYPE_QUALIFIER_LIST, $1, $2, NULL); }
			;

single_type_qualifier	: storage_qualifier { $$ = $1; }
			| layout_qualifier { $$ = $1; }
			| precision_qualifier { $$ = $1; }
			| interpolation_qualifier { $$ = $1; }
			| invariant_qualifier { $$ = $1; }
			| precise_qualifier { $$ = $1; }
			;

layout_qualifier	: LAYOUT LEFT_PAREN layout_qualifier_id_list RIGHT_PAREN { $$ = $3; }
			;

layout_qualifier_id_list: layout_qualifier_id { $$ = $1; }
			| layout_qualifier_id_list COMMA layout_qualifier_id { $$ = new_glsl_node(LAYOUT_QUALIFIER_ID_LIST, $1, $3, NULL); }
			;

layout_qualifier_id	: layout_identifier { $$ = new_glsl_node(LAYOUT_QUALIFIER_ID, $1, NULL); }
			| layout_identifier EQUAL constant_expression { $$ = new_glsl_node(LAYOUT_QUALIFIER_ID, $1, $3, NULL);}
			| SHARED { $$ = new_glsl_node(SHARED, NULL); }
			;

precision_qualifier	: HIGHP { $$ = new_glsl_node(HIGHP, NULL); }
			| MEDIUMP { $$ = new_glsl_node(MEDIUMP, NULL); }
			| LOWP { $$ = new_glsl_node(LOWP, NULL); }
			;

interpolation_qualifier : SMOOTH { $$ = new_glsl_node(SMOOTH, NULL); }
			| FLAT { $$ = new_glsl_node(FLAT, NULL); }
			| NOPERSPECTIVE { $$ = new_glsl_node(NOPERSPECTIVE, NULL); }
			;

invariant_qualifier	: INVARIANT { $$ = new_glsl_node(INVARIANT, NULL); }
			;

precise_qualifier 	: PRECISE { $$ = new_glsl_node(PRECISE, NULL); }
			;

storage_qualifier	: CONST { $$ = new_glsl_node(CONST, NULL); }
			| INOUT { $$ = new_glsl_node(INOUT, NULL); }
			| IN { $$ = new_glsl_node(IN, NULL); }
			| OUT { $$ = new_glsl_node(OUT, NULL); }
			| CENTROID { $$ = new_glsl_node(CENTROID, NULL); }
			| PATCH { $$ = new_glsl_node(PATCH, NULL); }
			| SAMPLE { $$ = new_glsl_node(SAMPLE, NULL); }
			| UNIFORM { $$ = new_glsl_node(UNIFORM, NULL); }
			| BUFFER { $$ = new_glsl_node(BUFFER, NULL); }
			| SHARED { $$ = new_glsl_node(SHARED, NULL); }
			| COHERENT { $$ = new_glsl_node(COHERENT, NULL); }
			| VOLATILE { $$ = new_glsl_node(VOLATILE, NULL); }
			| RESTRICT { $$ = new_glsl_node(RESTRICT, NULL); }
			| READONLY { $$ = new_glsl_node(READONLY, NULL); }
			| WRITEONLY { $$ = new_glsl_node(WRITEONLY, NULL); }
			| SUBROUTINE { $$ = new_glsl_node(SUBROUTINE, NULL); }
			| SUBROUTINE LEFT_PAREN type_name_list RIGHT_PAREN  { $$ = new_glsl_node(SUBROUTINE_TYPE, new_glsl_node(TYPE_NAME_LIST, $3, NULL), NULL); }
			;

type_name_list		: type_name { $$ = $1; }
			| type_name_list COMMA type_name { $$ = new_glsl_node(TYPE_NAME_LIST, $1, $3, NULL); }
			;

expression		: assignment_expression { $$ = $1; }
			| expression COMMA assignment_expression { $$ = new_glsl_node(COMMA, $1, $3, NULL); }
			;

assignment_expression	: conditional_expression { $$ = $1; }
			| unary_expression assignment_operator assignment_expression { $$ = new_glsl_node($2, $1, $3, NULL); }
			;

assignment_operator	: EQUAL { $$ = EQUAL; }
			| MUL_ASSIGN { $$ = MUL_ASSIGN; }
			| DIV_ASSIGN { $$ = DIV_ASSIGN; }
			| MOD_ASSIGN { $$ = MOD_ASSIGN; }
			| ADD_ASSIGN { $$ = ADD_ASSIGN; }
			| SUB_ASSIGN { $$ = SUB_ASSIGN; }
			| LEFT_ASSIGN { $$ = LEFT_ASSIGN; }
			| RIGHT_ASSIGN { $$ = RIGHT_ASSIGN; }
			| AND_ASSIGN { $$ = AND_ASSIGN; }
			| XOR_ASSIGN { $$ = XOR_ASSIGN; }
			| OR_ASSIGN { $$ = OR_ASSIGN; }
			;

constant_expression	: conditional_expression { $$ = $1; }
			;

conditional_expression	: logical_or_expression { $$ = $1; }
			| logical_or_expression QUESTION expression COLON assignment_expression { $$ = new_glsl_node(QUESTION, $1, $3, $5, NULL); }
			;

logical_or_expression	: logical_xor_expression { $$ = $1; }
			| logical_or_expression OR_OP logical_xor_expression { $$ = new_glsl_node(OR_OP, $1, $3, NULL); }
			;

logical_xor_expression	: logical_and_expression { $$ = $1; }
			| logical_xor_expression XOR_OP logical_and_expression { $$ = new_glsl_node(XOR_OP, $1, $3, NULL); }
			;

logical_and_expression	: inclusive_or_expression { $$ = $1; }
			| logical_and_expression AND_OP inclusive_or_expression { $$ = new_glsl_node(AND_OP, $1, $3, NULL); }
			;

inclusive_or_expression : exclusive_or_expression { $$ = $1; }
			| inclusive_or_expression VERTICAL_BAR exclusive_or_expression { $$ = new_glsl_node(VERTICAL_BAR, $1, $3, NULL); }
			;

exclusive_or_expression	: and_expression { $$ = $1; }
			| exclusive_or_expression CARET and_expression { $$ = new_glsl_node(CARET, $1, $3, NULL); }
			;

and_expression		: equality_expression { $$ = $1; }
			| and_expression AMPERSAND equality_expression { $$ = new_glsl_node(AMPERSAND, $1, $3, NULL); }
			;

equality_expression	: relational_expression { $$ = $1; }
			| equality_expression EQ_OP relational_expression { $$ = new_glsl_node(EQ_OP, $1, $3, NULL); }
			| equality_expression NE_OP relational_expression { $$ = new_glsl_node(NE_OP, $1, $3, NULL); }
			;

relational_expression	: shift_expression { $$ = $1; }
			| relational_expression LEFT_ANGLE shift_expression { $$ = new_glsl_node(LEFT_ANGLE, $1, $3, NULL); }
			| relational_expression RIGHT_ANGLE shift_expression { $$ = new_glsl_node(RIGHT_ANGLE, $1, $3, NULL); }
			| relational_expression LE_OP shift_expression { $$ = new_glsl_node(LE_OP, $1, $3, NULL); }
			| relational_expression GE_OP shift_expression { $$ = new_glsl_node(GE_OP, $1, $3, NULL); }
			;

shift_expression	: additive_expression { $$ = $1; }
			| shift_expression LEFT_OP additive_expression { $$ = new_glsl_node(LEFT_OP, $1, $3, NULL); }
			| shift_expression RIGHT_OP additive_expression { $$ = new_glsl_node(RIGHT_OP, $1, $3, NULL); }
			;

additive_expression	: multiplicative_expression { $$ = $1; }
			| additive_expression PLUS multiplicative_expression { $$ = new_glsl_node(PLUS, $1, $3, NULL); }
			| additive_expression DASH multiplicative_expression { $$ = new_glsl_node(DASH, $1, $3, NULL); }
			;

multiplicative_expression : unary_expression { $$ = $1; }
			| multiplicative_expression STAR unary_expression { $$ = new_glsl_node(STAR, $1, $3, NULL); }
			| multiplicative_expression SLASH unary_expression { $$ = new_glsl_node(SLASH, $1, $3, NULL); }
			| multiplicative_expression PERCENT unary_expression { $$ = new_glsl_node(PERCENT, $1, $3, NULL); }
			;

unary_expression	: postfix_expression { $$ = $1; }
			| INC_OP unary_expression { $$ = new_glsl_node(PRE_INC_OP, $2, NULL); }
			| DEC_OP unary_expression { $$ = new_glsl_node(PRE_DEC_OP, $2, NULL); }
			| unary_operator unary_expression { $$ = new_glsl_node($1, $2, NULL); }
			;

unary_operator		: PLUS { $$ = UNARY_PLUS; }
			| DASH { $$ = UNARY_DASH; }
			| BANG { $$ = BANG; }
			| TILDE { $$ = TILDE; }
			;

postfix_expression	: primary_expression { $$ = $1; }
			| postfix_expression LEFT_BRACKET integer_expression RIGHT_BRACKET { $$ = new_glsl_node(ARRAY_REF_OP, $1, $3, NULL); }
			| function_call { $$ = $1; }
			| postfix_expression DOT field_selection { $$ = new_glsl_node(DOT, $1, $3, NULL);}
			| postfix_expression INC_OP { $$ = new_glsl_node(POST_INC_OP, $1, NULL); }
			| postfix_expression DEC_OP { $$ = new_glsl_node(POST_DEC_OP, $1, NULL); }
			;

integer_expression	: expression { $$ = $1; }
			;

function_call		: function_call_or_method { $$ = $1; }
			;

function_call_or_method	: function_call_generic { $$ = $1; }
			;

function_call_generic	: function_identifier LEFT_PAREN function_call_parameter_list RIGHT_PAREN { $$ = new_glsl_node(FUNCTION_CALL, $1, $3, NULL); }
			| function_identifier LEFT_PAREN LEFT_PAREN { $$ = new_glsl_node(FUNCTION_CALL, $1, $$ = new_glsl_node(FUNCTION_CALL_PARAMETER_LIST, NULL), NULL); }
			| function_identifier LEFT_PAREN VOID RIGHT_PAREN { $$ = new_glsl_node(FUNCTION_CALL, $1, $$ = new_glsl_node(FUNCTION_CALL_PARAMETER_LIST, NULL), NULL); }
			;

function_call_parameter_list : assignment_expression { $$ = $1; }
			| function_call_parameter_list COMMA assignment_expression { $$ = new_glsl_node(FUNCTION_CALL_PARAMETER_LIST, $1, $3, NULL); }
			;
function_identifier	: type_specifier { $$ = $1; }
			| postfix_expression { $$ = new_glsl_node(POSTFIX_EXPRESSION, $1, NULL); }
			;

primary_expression	: variable_identifier { $$ = $1; }
			| INTCONSTANT { $$ = new_glsl_node(INTCONSTANT, NULL); $$->data.i = $1; }
			| UINTCONSTANT { $$ = new_glsl_node(UINTCONSTANT, NULL); $$->data.ui = $1; }
			| FLOATCONSTANT { $$ = new_glsl_node(FLOATCONSTANT, NULL); $$->data.f = $1; }
			| TRUE { $$ = new_glsl_node(TRUE, NULL); }
			| FALSE { $$ = new_glsl_node(FALSE, NULL); }
			| DOUBLECONSTANT { $$ = new_glsl_node(DOUBLECONSTANT, NULL); $$->data.d = $1; }
			| LEFT_PAREN expression RIGHT_PAREN { $$ = new_glsl_node(PAREN_EXPRESSION, $2, NULL); }
			;

%%

int list_length(struct glsl_node *n, int list_token)
{
	if (n->code != list_token) {
		return 1;
	} else {
		int i;
		int count = 0;
		for (i = 0; i < n->child_count; i++) {
			count += list_length(n->children[i], list_token);
		}
		return count;
	}
}

static void list_gather(struct glsl_node *n, struct glsl_node *new_list, int list_token)
{
	int i;
	for (i = 0; i < n->child_count; i++) {
		struct glsl_node *child = n->children[i];
		if (child->code != list_token)
			new_list->children[new_list->child_count++] = child;
		else
			list_gather(child, new_list, list_token);
	}
}

static void list_collapse(struct glsl_node *n)
{
	int i;
	for (i = 0; i < n->child_count; i++) {
		struct glsl_node *child = n->children[i];
		if (glsl_is_list_node(child)) {
			int list_token = child->code;
			int length = list_length(child, list_token);
			struct glsl_node *g = (struct glsl_node *)glsl_parse_alloc(offsetof(struct glsl_node, children[length]), 8);
			g->code = list_token;
			g->child_count = 0;
			list_gather(child, g, list_token);
			n->children[i] = g;
			child = g;
		}
		list_collapse(child);
	}
}

int main()
{
	glslparse();

	if (g_glsl_node_root) {
		if (glsl_is_list_node(g_glsl_node_root)) {
			//
			// list_collapse() can't combine all the TRANSLATION_UNIT nodes
			// since it would need to replace g_glsl_node_root so we combine
			// the TRANSLATION_UNIT nodes here.
			//
			int list_code = g_glsl_node_root->code;
			int length = list_length(g_glsl_node_root, list_code);
			struct glsl_node *new_root = (struct glsl_node *)glsl_parse_alloc(offsetof(struct glsl_node, children[length]), 8);
			new_root->code = TRANSLATION_UNIT;
			new_root->child_count = 0;
			list_gather(g_glsl_node_root, new_root, list_code);
			assert(new_root->child_count == length);
			g_glsl_node_root = new_root;
		}
		//
		// Collapse other list nodes
		//
		list_collapse(g_glsl_node_root);

		printf("\nAST tree:\n\n");
		glsl_print_ast_tree(g_glsl_node_root, 0);

		printf("\nRegenerated GLSL:\n\n");
		glsl_regen_tree(g_glsl_node_root, 0);
	}
}

