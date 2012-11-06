/*
 [The "BSD licence"]
 Copyright (c) 2007-2008 Terence Parr
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
 3. The name of the author may not be used to endorse or promote products
    derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/*
    Edited by Luca Boasso (lboasso@guidewire.com)  09/27/2012

    ADDED support for Java 1.7:
    - Type Inference for Generic Instance Creation:
        classOrInterfaceType supports the diamond syntax (typeArguments -> typeArgumentsOrDiamond)
        added typeArgumentsOrDiamond and nonWildcardTypeArgumentsOrDiamond
        modified innerCreator (typeArguments -> nonWildcardTypeArgumentsOrDiamond)
    - Try-with-resources Statement
        added (resourceSpecification)? to trystatement
        added resourceSpecification, resources, resource and variableDeclaratorId rules
    - Catching Multiple Exception Types and Rethrowing Exceptions with Improved Type Checking
        added catchType
        modified formalParameter (type -> catchType)
    - Strings in switch Statements (NO CHANGE needed)
    - Binary Literals
        added alternative "|   BINLITERAL" in literal
        added BINLITERAL, BinPrefix rules
    - Underscores in Numeric Literals
        modified IntegerNumber, NonIntegerNumber and Exponent
        added HexNumber

    FIXES:
    - forstatement supports C like array syntax in the enhanced for loop ->  added ('[' ']')*
    - added alternative "| '.' nonWildcardTypeArguments IDENTIFIER arguments" to selector
    - modified trystatement so that now the catches and the finally can be optional.
    - fixes in the lexer section
*/

/*
 * This file is modified by Yang Jiang (yang.jiang.z@gmail.com), taken from the original
 * java grammar in www.antlr.org, with the goal to provide a standard ANTLR grammar 
 * for java, as well as an implementation to construct the same AST trees as javac does.  
 * 
 * The major changes of this version as compared to the original version include:
 * 1) Top level rules are changed to include all of their sub-components. 
 *    For example, the rule
 * 
 *      classOrInterfaceDeclaration
 *          :   classOrInterfaceModifiers (classDeclaration | interfaceDeclaration)
 *      ;
 *
 *    is changed to
 * 
 *      classOrInterfaceDeclaration
 *          :   classDeclaration | interfaceDeclaration
 *      ;
 *    
 *    with classOrInterfaceModifiers been moved inside classDeclaration and 
 *    interfaceDeclaration.
 * 
 * 2) The original version is not quite clear on certain rules like memberDecl, 
 *    where it mixed the styles of listing of top level rules and listing of sub rules.
 *
 *    memberDecl
 *      :   genericMethodOrConstructorDecl
 *      |   memberDeclaration
 *      |   'void' Identifier voidMethodDeclaratorRest   
 *      |   Identifier constructorDeclaratorRest
 *      |   interfaceDeclaration
 *      |   classDeclaration
 *      ;
 *
 *    This is changed to a 
 *
 *    memberDecl
 *      :   fieldDeclaration        
 *      |   methodDeclaration
 *      |   classDeclaration
 *      |   interfaceDeclaration
 *      ;
 *    by folding similar rules into single rule.
 *
 * 3) Some syntactical predicates are added for efficiency, although this is not necessary 
 *    for correctness.
 *
 * 4) Lexer part is rewritten completely to construct tokens needed for the parser.
 * 
 * 5) This grammar adds more source level support
 *
 *
 * This grammar also adds bug fixes.
 *
 * 1) Adding typeArguments to superSuffix to alHexSignificandlow input like 
 *      super.<TYPE>method()
 * 
 * 2) Adding typeArguments to innerCreator to allow input like 
 *      new Type1<String, Integer>().new Type2<String>()
 * 
 * 3) conditionalExpression is changed to 
 *    conditionalExpression
 *      :   conditionalOrExpression ( '?' expression ':' conditionalExpression )?
 *      ;
 *    to accept input like 
 *      true?1:2=3
 *    
 *    Note: note this is by no means a valid input, by the grammar should be able to parse 
 *    this as 
 *            (true?1:2)=3  
 *    rather than    
 *            true?1:(2=3)
 *
 *  
 *  Know problems:
 *    Won't pass input containing unicode sequence like this 
 *      char c = '\uffff'
 *      String s = "\uffff";
 *    Because Antlr does not treat '\uffff' as an valid char. This will be fixed in the next Antlr 
 *    release. [Fixed in Antlr-3.1.1]
 * 
 *  Things to do:
 *    More effort to make this grammar faster.
 *    Error reporting/recovering.
 *  
 *  
 *  NOTE: If you try to compile this file from command line and Antlr gives an exception 
 *    like error message while compiling, add option 
 *    -Xconversiontimeout 100000
 *    to the command line.  
 *    If it still doesn't work or the compilation process
 *    takes too long, try to comment out the following two lines:
 *    |    {isValidSurrogateIdentifierStart((char)input.LT(1), (char)input.LT(2))}?=>('\ud800'..'\udbff') ('\udc00'..'\udfff')
 *    |    {isValidSurrogateIdentifierPart((char)input.LT(1), (char)input.LT(2))}?=>('\ud800'..'\udbff') ('\udc00'..'\udfff')
 *   
 *
 *  Below are comments found in the original version. 
 */


/** A Java 1.5 grammar for ANTLR v3 derived from the spec
 *
 *  This is a very close representation of the spec; the changes
 *  are comestic (remove left recursion) and also fixes (the spec
 *  isn't exactly perfect).  I have run this on the 1.4.2 source
 *  and some nasty looking enums from 1.5, but have not really
 *  tested for 1.5 compatibility.
 *
 *  I built this with: java -Xmx100M org.antlr.Tool java.g
 *  and got two errors that are ok (for now):
 *  java.g:691:9: Decision can match input such as
 *    "'0'..'9'{'E', 'e'}{'+', '-'}'0'..'9'{'D', 'F', 'd', 'f'}"
 *    using multiple alternatives: 3, 4
 *  As a result, alternative(s) 4 were disabled for that input
 *  java.g:734:35: Decision can match input such as "{'$', 'A'..'Z',
 *    '_', 'a'..'z', '\u00C0'..'\u00D6', '\u00D8'..'\u00F6',
 *    '\u00F8'..'\u1FFF', '\u3040'..'\u318F', '\u3300'..'\u337F',
 *    '\u3400'..'\u3D2D', '\u4E00'..'\u9FFF', '\uF900'..'\uFAFF'}"
 *    using multiple alternatives: 1, 2
 *  As a result, alternative(s) 2 were disabled for that input
 *
 *  You can turn enum on/off as a keyword :)
 *
 *  Version 1.0 -- initial release July 5, 2006 (requires 3.0b2 or higher)
 *
 *  Primary author: Terence Parr, July 2006
 *
 *  Version 1.0.1 -- corrections by Koen Vanderkimpen & Marko van Dooren,
 *      October 25, 2006;
 *      fixed normalInterfaceDeclaration: now uses typeParameters instead
 *          of typeParameter (according to JLS, 3rd edition)
 *      fixed castExpression: no longer allows expression next to type
 *          (according to semantics in JLS, in contrast with syntax in JLS)
 *
 *  Version 1.0.2 -- Terence Parr, Nov 27, 2006
 *      java spec I built this from had some bizarre for-loop control.
 *          Looked weird and so I looked elsewhere...Yep, it's messed up.
 *          simplified.
 *
 *  Version 1.0.3 -- Chris Hogue, Feb 26, 2007
 *      Factored out an annotationName rule and used it in the annotation rule.
 *          Not sure why, but typeName wasn't recognizing references to inner
 *          annotations (e.g. @InterfaceName.InnerAnnotation())
 *      Factored out the elementValue section of an annotation reference.  Created
 *          elementValuePair and elementValuePairs rules, then used them in the
 *          annotation rule.  Allows it to recognize annotation references with
 *          multiple, comma separated attributes.
 *      Updated elementValueArrayInitializer so that it allows multiple elements.
 *          (It was only allowing 0 or 1 element).
 *      Updated localVariableDeclaration to allow annotations.  Interestingly the JLS
 *          doesn't appear to indicate this is legal, but it does work as of at least
 *          JDK 1.5.0_06.
 *      Moved the Identifier portion of annotationTypeElementRest to annotationMethodRest.
 *          Because annotationConstantRest already references variableDeclarator which
 *          has the Identifier portion in it, the parser would fail on constants in
 *          annotation definitions because it expected two identifiers.
 *      Added optional trailing ';' to the alternatives in annotationTypeElementRest.
 *          Wouldn't handle an inner interface that has a trailing ';'.
 *      Swapped the expression and type rule reference order in castExpression to
 *          make it check for genericized casts first.  It was failing to recognize a
 *          statement like  "Class<Byte> TYPE = (Class<Byte>)...;" because it was seeing
 *          'Class<Byte' in the cast expression as a less than expression, then failing
 *          on the '>'.
 *      Changed createdName to use typeArguments instead of nonWildcardTypeArguments.
 *         
 *      Changed the 'this' alternative in primary to allow 'identifierSuffix' rather than
 *          just 'arguments'.  The case it couldn't handle was a call to an explicit
 *          generic method invocation (e.g. this.<E>doSomething()).  Using identifierSuffix
 *          may be overly aggressive--perhaps should create a more constrained thisSuffix rule?
 *
 *  Version 1.0.4 -- Hiroaki Nakamura, May 3, 2007
 *
 *  Fixed formalParameterDecls, localVariableDeclaration, forInit,
 *  and forVarControl to use variableModifier* not 'final'? (annotation)?
 *
 *  Version 1.0.5 -- Terence, June 21, 2007
 *  --a[i].foo didn't work. Fixed unaryExpression
 *
 *  Version 1.0.6 -- John Ridgway, March 17, 2008
 *      Made "assert" a switchable keyword like "enum".
 *      Fixed compilationUnit to disallow "annotation importDeclaration ...".
 *      Changed "Identifier ('.' Identifier)*" to "qualifiedName" in more
 *          places.
 *      Changed modifier* and/or variableModifier* to classOrInterfaceModifiers,
 *          modifiers or variableModifiers, as appropriate.
 *      Renamed "bound" to "typeBound" to better match language in the JLS.
 *      Added "memberDeclaration" which rewrites to methodDeclaration or
 *      fieldDeclaration and pulled type into memberDeclaration.  So we parse
 *          type and then move on to decide whether we're dealing with a field
 *          or a method.
 *      Modified "constructorDeclaration" to use "constructorBody" instead of
 *          "methodBody".  constructorBody starts with explicitConstructorInvocation,
 *          then goes on to blockStatement*.  Pulling explicitConstructorInvocation
 *          out of expressions allowed me to simplify "primary".
 *      Changed variableDeclarator to simplify it.
 *      Changed type to use classOrInterfaceType, thus simplifying it; of course
 *          I then had to add classOrInterfaceType, but it is used in several
 *          places.
 *      Fixed annotations, old version allowed "@X(y,z)", which is illegal.
 *      Added optional comma to end of "elementValueArrayInitializer"; as per JLS.
 *      Changed annotationTypeElementRest to use normalClassDeclaration and
 *          normalInterfaceDeclaration rather than classDeclaration and
 *          interfaceDeclaration, thus getting rid of a couple of grammar ambiguities.
 *      Split localVariableDeclaration into localVariableDeclarationStatement
 *          (includes the terminating semi-colon) and localVariableDeclaration.
 *          This allowed me to use localVariableDeclaration in "forInit" clauses,
 *           simplifying them.
 *      Changed switchBlockStatementGroup to use multiple labels.  This adds an
 *          ambiguity, but if one uses appropriately greedy parsing it yields the
 *           parse that is closest to the meaning of the switch statement.
 *      Renamed "forVarControl" to "enhancedForControl" -- JLS language.
 *      Added semantic predicates to test for shift operations rather than other
 *          things.  Thus, for instance, the string "< <" will never be treated
 *          as a left-shift operator.
 *      In "creator" we rule out "nonWildcardTypeArguments" on arrayCreation,
 *          which are illegal.
 *      Moved "nonWildcardTypeArguments into innerCreator.
 *      Removed 'super' superSuffix from explicitGenericInvocation, since that
 *          is only used in explicitConstructorInvocation at the beginning of a
 *           constructorBody.  (This is part of the simplification of expressions
 *           mentioned earlier.)
 *      Simplified primary (got rid of those things that are only used in
 *          explicitConstructorInvocation).
 *      Lexer -- removed "Exponent?" from FloatingPointLiteral choice 4, since it
 *          led to an ambiguity.
 *
 *      This grammar successfully parses every .java file in the JDK 1.5 source
 *          tree (excluding those whose file names include '-', which are not
 *          valid Java compilation units).
 *
 *  Known remaining problems:
 *      "Letter" and "JavaIDDigit" are wrong.  The actual specification of
 *      "Letter" should be "a character for which the method
 *      Character.isJavaIdentifierStart(int) returns true."  A "Java
 *      letter-or-digit is a character for which the method
 *      Character.isJavaIdentifierPart(int) returns true."
 */   
 
 
 /* 
    This is a merged file, containing two versions of the Java.g grammar.
    To extract a version from the file, run the ver.jar with the command provided below.
    
    Version 1 - tree building version, with all source level support, error recovery etc.
                This is the version for compiler grammar workspace.
                This version can be extracted by invoking:
                java -cp ver.jar Main 1 true true true true true Java.g
                             
    Version 2 - clean version, with no source leve support, no error recovery, no predicts, 
                assumes 1.6 level, works in Antlrworks.
                This is the version for Alex.
                This version can be extracted by invoking:
                java -cp ver.jar Main 2 false false false false false Java.g 
*/

grammar Java;

options {
    backtrack=true;
    memoize=true;
}

@header{
package gw.internal.gosu.parser.java;
}

@lexer::header{
package gw.internal.gosu.parser.java;
}

@members{
    private TreeBuilder T;

    public void setTreeBuilder(TreeBuilder T){
        this.T = T;
    }

    public void displayRecognitionError(String[] tokenNames, RecognitionException e) {
    }
}

@lexer::members{
    public void displayRecognitionError(String[] tokenNames, RecognitionException e) {
    }
}

compilationUnit
    :   (   ({T.pushTop();T.setCurrentParent(T.addNode("annotations"));} t0=annotations {T.popTop().setTextRange($t0.start, $t0.stop);}
            )?
            {T.pushTop();T.setCurrentParent(T.addNode("packageDeclaration"));} t1=packageDeclaration {T.popTop().setTextRange($t1.start, $t1.stop);}
        )?
        ({T.pushTop();T.setCurrentParent(T.addNode("importDeclaration"));} t2=importDeclaration {T.popTop().setTextRange($t2.start, $t2.stop);}
        )*
        ({T.pushTop();T.setCurrentParent(T.addNode("typeDeclaration"));} t3=typeDeclaration {T.popTop().setTextRange($t3.start, $t3.stop);}
        )*
    ;

packageDeclaration 
    :   'package'{T.addLeaf("'package'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("qualifiedName"));} t4=qualifiedName {T.popTop().setTextRange($t4.start, $t4.stop);}
        (';'{T.addLeaf("';'",input.LT(-1));})
    ;

importDeclaration  
    :   'import'{T.addLeaf("'import'",input.LT(-1));} 
        ('static'{T.addLeaf("'static'",input.LT(-1));}
        )?
        IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));} ('.'{T.addLeaf("'.'",input.LT(-1));}) ('*'{T.addLeaf("'*'",input.LT(-1));})
        (';'{T.addLeaf("';'",input.LT(-1));})       
    |   'import'{T.addLeaf("'import'",input.LT(-1));} 
        ('static'{T.addLeaf("'static'",input.LT(-1));}
        )?
        IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        (('.'{T.addLeaf("'.'",input.LT(-1));}) IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        )+
        (('.'{T.addLeaf("'.'",input.LT(-1));}) ('*'{T.addLeaf("'*'",input.LT(-1));})
        )?
        (';'{T.addLeaf("';'",input.LT(-1));})
    ;

qualifiedImportName 
    :   IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        (('.'{T.addLeaf("'.'",input.LT(-1));}) IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        )*
    ;

typeDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("classOrInterfaceDeclaration"));} t5=classOrInterfaceDeclaration {T.popTop().setTextRange($t5.start, $t5.stop);}
    |   (';'{T.addLeaf("';'",input.LT(-1));})
    ;

classOrInterfaceDeclaration 
    :    {T.pushTop();T.setCurrentParent(T.addNode("classDeclaration"));} t6=classDeclaration {T.popTop().setTextRange($t6.start, $t6.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("interfaceDeclaration"));} t7=interfaceDeclaration {T.popTop().setTextRange($t7.start, $t7.stop);}
    ;
    
  
modifiers  
    :
    (    {T.pushTop();T.setCurrentParent(T.addNode("annotation"));} t8=annotation {T.popTop().setTextRange($t8.start, $t8.stop);}
    |   'public'{T.addLeaf("'public'",input.LT(-1));}
    |   'protected'{T.addLeaf("'protected'",input.LT(-1));}
    |   'private'{T.addLeaf("'private'",input.LT(-1));}
    |   'static'{T.addLeaf("'static'",input.LT(-1));}
    |   'abstract'{T.addLeaf("'abstract'",input.LT(-1));}
    |   'final'{T.addLeaf("'final'",input.LT(-1));}
    |   'native'{T.addLeaf("'native'",input.LT(-1));}
    |   'synchronized'{T.addLeaf("'synchronized'",input.LT(-1));}
    |   'transient'{T.addLeaf("'transient'",input.LT(-1));}
    |   'volatile'{T.addLeaf("'volatile'",input.LT(-1));}
    |   'strictfp'{T.addLeaf("'strictfp'",input.LT(-1));}
    )*
    {
       Token cur = $modifiers.start;
       if(cur.getTokenIndex() > 0) {
           Token prev = getTokenStream().get(cur.getTokenIndex()-1);
           if(prev.getChannel() == Token.HIDDEN_CHANNEL) {
               if (prev.getText().contains("@deprecated")) {
                   T.pushTop();T.setCurrentParent(T.addNode("annotation"));
                   T.addLeaf("'@'",new CommonToken(MONKEYS_AT, "@"));
                   T.pushTop();T.setCurrentParent(T.addNode("qualifiedName"));
                   T.addLeaf("IDENTIFIER['Deprecated']", new CommonToken(IDENTIFIER, "Deprecated") );
                   T.popTop();
                   T.popTop();
               }
           }
       }
    }
    ;


variableModifiers 
    :   (   'final'{T.addLeaf("'final'",input.LT(-1));}
        |   {T.pushTop();T.setCurrentParent(T.addNode("annotation"));} t9=annotation {T.popTop().setTextRange($t9.start, $t9.stop);}
        )*
    ;
    

classDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("normalClassDeclaration"));} t10=normalClassDeclaration {T.popTop().setTextRange($t10.start, $t10.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("enumDeclaration"));} t11=enumDeclaration {T.popTop().setTextRange($t11.start, $t11.stop);}
    ;

normalClassDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("modifiers"));} t12=modifiers {T.popTop().setTextRange($t12.start, $t12.stop);}  'class'{T.addLeaf("'class'",input.LT(-1));} IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        ({T.pushTop();T.setCurrentParent(T.addNode("typeParameters"));} t13=typeParameters {T.popTop().setTextRange($t13.start, $t13.stop);}
        )?
        ('extends'{T.addLeaf("'extends'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("type"));} t14=type {T.popTop().setTextRange($t14.start, $t14.stop);}
        )?
        ('implements'{T.addLeaf("'implements'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("typeList"));} t15=typeList {T.popTop().setTextRange($t15.start, $t15.stop);}
        )?            
        {T.pushTop();T.setCurrentParent(T.addNode("classBody"));} t16=classBody {T.popTop().setTextRange($t16.start, $t16.stop);}
    ;


typeParameters 
    :   ('<'{T.addLeaf("'<'",input.LT(-1));})
            {T.pushTop();T.setCurrentParent(T.addNode("typeParameter"));} t17=typeParameter {T.popTop().setTextRange($t17.start, $t17.stop);}
            ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("typeParameter"));} t18=typeParameter {T.popTop().setTextRange($t18.start, $t18.stop);}
            )*
        ('>'{T.addLeaf("'>'",input.LT(-1));})
    ;

typeParameter 
    :   IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        ('extends'{T.addLeaf("'extends'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("typeBound"));} t19=typeBound {T.popTop().setTextRange($t19.start, $t19.stop);}
        )?
    ;


typeBound 
    :   {T.pushTop();T.setCurrentParent(T.addNode("type"));} t20=type {T.popTop().setTextRange($t20.start, $t20.stop);}
        (('&'{T.addLeaf("'&'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("type"));} t21=type {T.popTop().setTextRange($t21.start, $t21.stop);}
        )*
    ;


enumDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("modifiers"));} t22=modifiers {T.popTop().setTextRange($t22.start, $t22.stop);} 
        ('enum'{T.addLeaf("'enum'",input.LT(-1));}
        ) 
        IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        ('implements'{T.addLeaf("'implements'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("typeList"));} t23=typeList {T.popTop().setTextRange($t23.start, $t23.stop);}
        )?
        {T.pushTop();T.setCurrentParent(T.addNode("enumBody"));} t24=enumBody {T.popTop().setTextRange($t24.start, $t24.stop);}
    ;
    

enumBody 
    :   ('{'{T.addLeaf("'{'",input.LT(-1));})
        ({T.pushTop();T.setCurrentParent(T.addNode("enumConstants"));} t25=enumConstants {T.popTop().setTextRange($t25.start, $t25.stop);}
        )? 
        (','{T.addLeaf("','",input.LT(-1));})? 
        ({T.pushTop();T.setCurrentParent(T.addNode("enumBodyDeclarations"));} t26=enumBodyDeclarations {T.popTop().setTextRange($t26.start, $t26.stop);}
        )? 
        ('}'{T.addLeaf("'}'",input.LT(-1));})
    ;

enumConstants 
    :   {T.pushTop();T.setCurrentParent(T.addNode("enumConstant"));} t27=enumConstant {T.popTop().setTextRange($t27.start, $t27.stop);}
        ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("enumConstant"));} t28=enumConstant {T.popTop().setTextRange($t28.start, $t28.stop);}
        )*
    ;

/**
 * NOTE: here differs from the javac grammar, missing TypeArguments.
 * EnumeratorDeclaration = AnnotationsOpt [TypeArguments] IDENTIFIER [ Arguments ] [ "{" ClassBody "}" ]
 */
enumConstant 
    :   ({T.pushTop();T.setCurrentParent(T.addNode("annotations"));} t29=annotations {T.popTop().setTextRange($t29.start, $t29.stop);}
        )?
        IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        ({T.pushTop();T.setCurrentParent(T.addNode("arguments"));} t30=arguments {T.popTop().setTextRange($t30.start, $t30.stop);}
        )?
        ({T.pushTop();T.setCurrentParent(T.addNode("classBody"));} t31=classBody {T.popTop().setTextRange($t31.start, $t31.stop);}
        )?
        /* TODO: $GScope::name = names.empty. enum constant body is actually
        an anonymous class, where constructor isn't allowed, have to add this check*/
    ;

enumBodyDeclarations 
    :   (';'{T.addLeaf("';'",input.LT(-1));}) 
        ({T.pushTop();T.setCurrentParent(T.addNode("classBodyDeclaration"));} t32=classBodyDeclaration {T.popTop().setTextRange($t32.start, $t32.stop);}
        )*
    ;

interfaceDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("normalInterfaceDeclaration"));} t33=normalInterfaceDeclaration {T.popTop().setTextRange($t33.start, $t33.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("annotationTypeDeclaration"));} t34=annotationTypeDeclaration {T.popTop().setTextRange($t34.start, $t34.stop);}
    ;
    
normalInterfaceDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("modifiers"));} t35=modifiers {T.popTop().setTextRange($t35.start, $t35.stop);} 'interface'{T.addLeaf("'interface'",input.LT(-1));} IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        ({T.pushTop();T.setCurrentParent(T.addNode("typeParameters"));} t36=typeParameters {T.popTop().setTextRange($t36.start, $t36.stop);}
        )?
        ('extends'{T.addLeaf("'extends'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("typeList"));} t37=typeList {T.popTop().setTextRange($t37.start, $t37.stop);}
        )?
        {T.pushTop();T.setCurrentParent(T.addNode("interfaceBody"));} t38=interfaceBody {T.popTop().setTextRange($t38.start, $t38.stop);}
    ;

typeList 
    :   {T.pushTop();T.setCurrentParent(T.addNode("type"));} t39=type {T.popTop().setTextRange($t39.start, $t39.stop);}
        ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("type"));} t40=type {T.popTop().setTextRange($t40.start, $t40.stop);}
        )*
    ;

classBody 
    :   ('{'{T.addLeaf("'{'",input.LT(-1));}) 
        ({T.pushTop();T.setCurrentParent(T.addNode("classBodyDeclaration"));} t41=classBodyDeclaration {T.popTop().setTextRange($t41.start, $t41.stop);}
        )* 
        ('}'{T.addLeaf("'}'",input.LT(-1));})
    ;

interfaceBody 
    :   ('{'{T.addLeaf("'{'",input.LT(-1));}) 
        ({T.pushTop();T.setCurrentParent(T.addNode("interfaceBodyDeclaration"));} t42=interfaceBodyDeclaration {T.popTop().setTextRange($t42.start, $t42.stop);}
        )* 
        ('}'{T.addLeaf("'}'",input.LT(-1));})
    ;

classBodyDeclaration 
    :   (';'{T.addLeaf("';'",input.LT(-1));})
    |   ('static'{T.addLeaf("'static'",input.LT(-1));}
        )? 
        {T.pushTop();T.setCurrentParent(T.addNode("block"));} t43=block {T.popTop().setTextRange($t43.start, $t43.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("memberDecl"));} t44=memberDecl {T.popTop().setTextRange($t44.start, $t44.stop);}
    ;

memberDecl 
    :    {T.pushTop();T.setCurrentParent(T.addNode("fieldDeclaration"));} t45=fieldDeclaration {T.popTop().setTextRange($t45.start, $t45.stop);}
    |    {T.pushTop();T.setCurrentParent(T.addNode("methodDeclaration"));} t46=methodDeclaration {T.popTop().setTextRange($t46.start, $t46.stop);}
    |    {T.pushTop();T.setCurrentParent(T.addNode("classDeclaration"));} t47=classDeclaration {T.popTop().setTextRange($t47.start, $t47.stop);}
    |    {T.pushTop();T.setCurrentParent(T.addNode("interfaceDeclaration"));} t48=interfaceDeclaration {T.popTop().setTextRange($t48.start, $t48.stop);}
    ;


methodDeclaration 
    :
        /* For constructor, return type is null, name is 'init' */
         {T.pushTop();T.setCurrentParent(T.addNode("modifiers"));} t49=modifiers {T.popTop().setTextRange($t49.start, $t49.stop);}
        ({T.pushTop();T.setCurrentParent(T.addNode("typeParameters"));} t50=typeParameters {T.popTop().setTextRange($t50.start, $t50.stop);}
        )?
        IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        {T.pushTop();T.setCurrentParent(T.addNode("formalParameters"));} t51=formalParameters {T.popTop().setTextRange($t51.start, $t51.stop);}
        ('throws'{T.addLeaf("'throws'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("qualifiedNameList"));} t52=qualifiedNameList {T.popTop().setTextRange($t52.start, $t52.stop);}
        )?
        ('{'{T.addLeaf("'{'",input.LT(-1));}) 
        ({T.pushTop();T.setCurrentParent(T.addNode("explicitConstructorInvocation"));} t53=explicitConstructorInvocation {T.popTop().setTextRange($t53.start, $t53.stop);}
        )?
        ({T.pushTop();T.setCurrentParent(T.addNode("blockStatement"));} t54=blockStatement {T.popTop().setTextRange($t54.start, $t54.stop);}
        )*
        ('}'{T.addLeaf("'}'",input.LT(-1));})
    |   {T.pushTop();T.setCurrentParent(T.addNode("modifiers"));} t55=modifiers {T.popTop().setTextRange($t55.start, $t55.stop);}
        ({T.pushTop();T.setCurrentParent(T.addNode("typeParameters"));} t56=typeParameters {T.popTop().setTextRange($t56.start, $t56.stop);}
        )?
        ({T.pushTop();T.setCurrentParent(T.addNode("type"));} t57=type {T.popTop().setTextRange($t57.start, $t57.stop);}
        |   'void'{T.addLeaf("'void'",input.LT(-1));}
        )
        IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        {T.pushTop();T.setCurrentParent(T.addNode("formalParameters"));} t58=formalParameters {T.popTop().setTextRange($t58.start, $t58.stop);}
        (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));})
        )*
        ('throws'{T.addLeaf("'throws'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("qualifiedNameList"));} t59=qualifiedNameList {T.popTop().setTextRange($t59.start, $t59.stop);}
        )?            
        (        
            {T.pushTop();T.setCurrentParent(T.addNode("block"));} t60=block {T.popTop().setTextRange($t60.start, $t60.stop);}
        |   (';'{T.addLeaf("';'",input.LT(-1));}) 
        )
    ;


fieldDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("modifiers"));} t61=modifiers {T.popTop().setTextRange($t61.start, $t61.stop);}
        {T.pushTop();T.setCurrentParent(T.addNode("type"));} t62=type {T.popTop().setTextRange($t62.start, $t62.stop);}
        {T.pushTop();T.setCurrentParent(T.addNode("variableDeclarator"));} t63=variableDeclarator {T.popTop().setTextRange($t63.start, $t63.stop);}
        ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("variableDeclarator"));} t64=variableDeclarator {T.popTop().setTextRange($t64.start, $t64.stop);}
        )*
        (';'{T.addLeaf("';'",input.LT(-1));})
    ;

variableDeclarator 
    :   IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));})
        )*
        (('='{T.addLeaf("'='",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("variableInitializer"));} t65=variableInitializer {T.popTop().setTextRange($t65.start, $t65.stop);}
        )?
    ;

/**
 *TODO: add predicates
 */
interfaceBodyDeclaration 
    :
        {T.pushTop();T.setCurrentParent(T.addNode("interfaceFieldDeclaration"));} t66=interfaceFieldDeclaration {T.popTop().setTextRange($t66.start, $t66.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("interfaceMethodDeclaration"));} t67=interfaceMethodDeclaration {T.popTop().setTextRange($t67.start, $t67.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("interfaceDeclaration"));} t68=interfaceDeclaration {T.popTop().setTextRange($t68.start, $t68.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("classDeclaration"));} t69=classDeclaration {T.popTop().setTextRange($t69.start, $t69.stop);}
    |   (';'{T.addLeaf("';'",input.LT(-1));})
    ;

interfaceMethodDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("modifiers"));} t70=modifiers {T.popTop().setTextRange($t70.start, $t70.stop);}
        ({T.pushTop();T.setCurrentParent(T.addNode("typeParameters"));} t71=typeParameters {T.popTop().setTextRange($t71.start, $t71.stop);}
        )?
        ({T.pushTop();T.setCurrentParent(T.addNode("type"));} t72=type {T.popTop().setTextRange($t72.start, $t72.stop);}
        |'void'{T.addLeaf("'void'",input.LT(-1));}
        )
        IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        {T.pushTop();T.setCurrentParent(T.addNode("formalParameters"));} t73=formalParameters {T.popTop().setTextRange($t73.start, $t73.stop);}
        (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));})
        )*
        ('throws'{T.addLeaf("'throws'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("qualifiedNameList"));} t74=qualifiedNameList {T.popTop().setTextRange($t74.start, $t74.stop);}
        )? (';'{T.addLeaf("';'",input.LT(-1));})
    ;

/**
 * NOTE, should not use variableDeclarator here, as it doesn't necessary require
 * an initializer, while an interface field does, or judge by the returned value.
 * But this gives better diagnostic message, or antlr won't predict this rule.
 */
interfaceFieldDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("modifiers"));} t75=modifiers {T.popTop().setTextRange($t75.start, $t75.stop);} {T.pushTop();T.setCurrentParent(T.addNode("type"));} t76=type {T.popTop().setTextRange($t76.start, $t76.stop);} {T.pushTop();T.setCurrentParent(T.addNode("variableDeclarator"));} t77=variableDeclarator {T.popTop().setTextRange($t77.start, $t77.stop);}
        ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("variableDeclarator"));} t78=variableDeclarator {T.popTop().setTextRange($t78.start, $t78.stop);}
        )*
        (';'{T.addLeaf("';'",input.LT(-1));})
    ;


type 
    :   {T.pushTop();T.setCurrentParent(T.addNode("classOrInterfaceType"));} t79=classOrInterfaceType {T.popTop().setTextRange($t79.start, $t79.stop);}
        (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));})
        )*
    |   {T.pushTop();T.setCurrentParent(T.addNode("primitiveType"));} t80=primitiveType {T.popTop().setTextRange($t80.start, $t80.stop);}
        (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));})
        )*
    ;


classOrInterfaceType 
    :   IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        ({T.pushTop();T.setCurrentParent(T.addNode("typeArgumentsOrDiamond"));} t81=typeArgumentsOrDiamond {T.popTop().setTextRange($t81.start, $t81.stop);}
        )?
        (('.'{T.addLeaf("'.'",input.LT(-1));}) IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
            ({T.pushTop();T.setCurrentParent(T.addNode("typeArgumentsOrDiamond"));} t82=typeArgumentsOrDiamond {T.popTop().setTextRange($t82.start, $t82.stop);}
            )?
        )*
    ;

primitiveType  
    :   'boolean'{T.addLeaf("'boolean'",input.LT(-1));}
    |   'char'{T.addLeaf("'char'",input.LT(-1));}
    |   'byte'{T.addLeaf("'byte'",input.LT(-1));}
    |   'short'{T.addLeaf("'short'",input.LT(-1));}
    |   'int'{T.addLeaf("'int'",input.LT(-1));}
    |   'long'{T.addLeaf("'long'",input.LT(-1));}
    |   'float'{T.addLeaf("'float'",input.LT(-1));}
    |   'double'{T.addLeaf("'double'",input.LT(-1));}
    ;

typeArguments 
    :   ('<'{T.addLeaf("'<'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("typeArgument"));} t83=typeArgument {T.popTop().setTextRange($t83.start, $t83.stop);}
        ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("typeArgument"));} t84=typeArgument {T.popTop().setTextRange($t84.start, $t84.stop);}
        )* 
        ('>'{T.addLeaf("'>'",input.LT(-1));})
    ;

typeArgument 
    :   {T.pushTop();T.setCurrentParent(T.addNode("type"));} t85=type {T.popTop().setTextRange($t85.start, $t85.stop);}
    |   ('?'{T.addLeaf("'?'",input.LT(-1));})
        (
            ('extends'{T.addLeaf("'extends'",input.LT(-1));}
            |'super'{T.addLeaf("'super'",input.LT(-1));}
            )
            {T.pushTop();T.setCurrentParent(T.addNode("type"));} t86=type {T.popTop().setTextRange($t86.start, $t86.stop);}
        )?
    ;

qualifiedNameList 
    :   {T.pushTop();T.setCurrentParent(T.addNode("qualifiedName"));} t87=qualifiedName {T.popTop().setTextRange($t87.start, $t87.stop);}
        ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("qualifiedName"));} t88=qualifiedName {T.popTop().setTextRange($t88.start, $t88.stop);}
        )*
    ;

formalParameters 
    :   ('('{T.addLeaf("'('",input.LT(-1));})
        ({T.pushTop();T.setCurrentParent(T.addNode("formalParameterDecls"));} t89=formalParameterDecls {T.popTop().setTextRange($t89.start, $t89.stop);}
        )? 
        (')'{T.addLeaf("')'",input.LT(-1));})
    ;

formalParameterDecls 
    :   {T.pushTop();T.setCurrentParent(T.addNode("ellipsisParameterDecl"));} t90=ellipsisParameterDecl {T.popTop().setTextRange($t90.start, $t90.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("normalParameterDecl"));} t91=normalParameterDecl {T.popTop().setTextRange($t91.start, $t91.stop);}
        ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("normalParameterDecl"));} t92=normalParameterDecl {T.popTop().setTextRange($t92.start, $t92.stop);}
        )*
    |   ({T.pushTop();T.setCurrentParent(T.addNode("normalParameterDecl"));} t93=normalParameterDecl {T.popTop().setTextRange($t93.start, $t93.stop);}
        (','{T.addLeaf("','",input.LT(-1));})
        )+ 
        {T.pushTop();T.setCurrentParent(T.addNode("ellipsisParameterDecl"));} t94=ellipsisParameterDecl {T.popTop().setTextRange($t94.start, $t94.stop);}
    ;

normalParameterDecl 
    :   {T.pushTop();T.setCurrentParent(T.addNode("variableModifiers"));} t95=variableModifiers {T.popTop().setTextRange($t95.start, $t95.stop);} {T.pushTop();T.setCurrentParent(T.addNode("type"));} t96=type {T.popTop().setTextRange($t96.start, $t96.stop);} IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));})
        )*
    ;

ellipsisParameterDecl 
    :   {T.pushTop();T.setCurrentParent(T.addNode("variableModifiers"));} t97=variableModifiers {T.popTop().setTextRange($t97.start, $t97.stop);}
        {T.pushTop();T.setCurrentParent(T.addNode("type"));} t98=type {T.popTop().setTextRange($t98.start, $t98.stop);}  '...'{T.addLeaf("'...'",input.LT(-1));}
        IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
    ;


explicitConstructorInvocation 
    :   ({T.pushTop();T.setCurrentParent(T.addNode("nonWildcardTypeArguments"));} t99=nonWildcardTypeArguments {T.popTop().setTextRange($t99.start, $t99.stop);}
        )?     //NOTE: the position of Identifier 'super' is set to the type args position here
        ('this'{T.addLeaf("'this'",input.LT(-1));}
        |'super'{T.addLeaf("'super'",input.LT(-1));}
        )
        {T.pushTop();T.setCurrentParent(T.addNode("arguments"));} t100=arguments {T.popTop().setTextRange($t100.start, $t100.stop);} (';'{T.addLeaf("';'",input.LT(-1));})

    |   {T.pushTop();T.setCurrentParent(T.addNode("primary"));} t101=primary {T.popTop().setTextRange($t101.start, $t101.stop);}
        ('.'{T.addLeaf("'.'",input.LT(-1));})
        ({T.pushTop();T.setCurrentParent(T.addNode("nonWildcardTypeArguments"));} t102=nonWildcardTypeArguments {T.popTop().setTextRange($t102.start, $t102.stop);}
        )?
        'super'{T.addLeaf("'super'",input.LT(-1));}
        {T.pushTop();T.setCurrentParent(T.addNode("arguments"));} t103=arguments {T.popTop().setTextRange($t103.start, $t103.stop);} (';'{T.addLeaf("';'",input.LT(-1));})
    ;

qualifiedName 
    :   IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        (('.'{T.addLeaf("'.'",input.LT(-1));}) IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        )*
    ;

annotations 
    :   ({T.pushTop();T.setCurrentParent(T.addNode("annotation"));} t104=annotation {T.popTop().setTextRange($t104.start, $t104.stop);}
        )+
    ;

/**
 *  Using an annotation. 
 * '@' is flaged in modifier
 */
annotation 
    :   ('@'{T.addLeaf("'@'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("qualifiedName"));} t105=qualifiedName {T.popTop().setTextRange($t105.start, $t105.stop);}
        (   ('('{T.addLeaf("'('",input.LT(-1));})   
                  (   {T.pushTop();T.setCurrentParent(T.addNode("elementValuePairs"));} t106=elementValuePairs {T.popTop().setTextRange($t106.start, $t106.stop);}
                  |   {T.pushTop();T.setCurrentParent(T.addNode("elementValue"));} t107=elementValue {T.popTop().setTextRange($t107.start, $t107.stop);}
                  )? 
            (')'{T.addLeaf("')'",input.LT(-1));}) 
        )?
    ;

elementValuePairs 
    :   {T.pushTop();T.setCurrentParent(T.addNode("elementValuePair"));} t108=elementValuePair {T.popTop().setTextRange($t108.start, $t108.stop);}
        ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("elementValuePair"));} t109=elementValuePair {T.popTop().setTextRange($t109.start, $t109.stop);}
        )*
    ;

elementValuePair 
    :   IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));} ('='{T.addLeaf("'='",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("elementValue"));} t110=elementValue {T.popTop().setTextRange($t110.start, $t110.stop);}
    ;

elementValue 
    :   {T.pushTop();T.setCurrentParent(T.addNode("conditionalExpression"));} t111=conditionalExpression {T.popTop().setTextRange($t111.start, $t111.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("annotation"));} t112=annotation {T.popTop().setTextRange($t112.start, $t112.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("elementValueArrayInitializer"));} t113=elementValueArrayInitializer {T.popTop().setTextRange($t113.start, $t113.stop);}
    ;

elementValueArrayInitializer 
    :   ('{'{T.addLeaf("'{'",input.LT(-1));})
        ({T.pushTop();T.setCurrentParent(T.addNode("elementValue"));} t114=elementValue {T.popTop().setTextRange($t114.start, $t114.stop);}
            ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("elementValue"));} t115=elementValue {T.popTop().setTextRange($t115.start, $t115.stop);}
            )*
        )? ((','{T.addLeaf("','",input.LT(-1));}))? ('}'{T.addLeaf("'}'",input.LT(-1));})
    ;


/**
 * Annotation declaration.
 */
annotationTypeDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("modifiers"));} t116=modifiers {T.popTop().setTextRange($t116.start, $t116.stop);} ('@'{T.addLeaf("'@'",input.LT(-1));})
        'interface'{T.addLeaf("'interface'",input.LT(-1));}
        IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        {T.pushTop();T.setCurrentParent(T.addNode("annotationTypeBody"));} t117=annotationTypeBody {T.popTop().setTextRange($t117.start, $t117.stop);}
    ;


annotationTypeBody 
    :   ('{'{T.addLeaf("'{'",input.LT(-1));}) 
        ({T.pushTop();T.setCurrentParent(T.addNode("annotationTypeElementDeclaration"));} t118=annotationTypeElementDeclaration {T.popTop().setTextRange($t118.start, $t118.stop);}
        )* 
        ('}'{T.addLeaf("'}'",input.LT(-1));})
    ;

/**
 * NOTE: here use interfaceFieldDeclaration for field declared inside annotation. they are sytactically the same.
 */
annotationTypeElementDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("annotationMethodDeclaration"));} t119=annotationMethodDeclaration {T.popTop().setTextRange($t119.start, $t119.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("interfaceFieldDeclaration"));} t120=interfaceFieldDeclaration {T.popTop().setTextRange($t120.start, $t120.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("normalClassDeclaration"));} t121=normalClassDeclaration {T.popTop().setTextRange($t121.start, $t121.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("normalInterfaceDeclaration"));} t122=normalInterfaceDeclaration {T.popTop().setTextRange($t122.start, $t122.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("enumDeclaration"));} t123=enumDeclaration {T.popTop().setTextRange($t123.start, $t123.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("annotationTypeDeclaration"));} t124=annotationTypeDeclaration {T.popTop().setTextRange($t124.start, $t124.stop);}
    |   (';'{T.addLeaf("';'",input.LT(-1));})
    ;

annotationMethodDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("modifiers"));} t125=modifiers {T.popTop().setTextRange($t125.start, $t125.stop);} {T.pushTop();T.setCurrentParent(T.addNode("type"));} t126=type {T.popTop().setTextRange($t126.start, $t126.stop);} IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        ('('{T.addLeaf("'('",input.LT(-1));}) (')'{T.addLeaf("')'",input.LT(-1));}) ('default'{T.addLeaf("'default'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("elementValue"));} t127=elementValue {T.popTop().setTextRange($t127.start, $t127.stop);}
                )?
        (';'{T.addLeaf("';'",input.LT(-1));})
        ;

block 
    :   ('{'{T.addLeaf("'{'",input.LT(-1));})
        ({T.pushTop();T.setCurrentParent(T.addNode("blockStatement"));} t128=blockStatement {T.popTop().setTextRange($t128.start, $t128.stop);}
        )*
        ('}'{T.addLeaf("'}'",input.LT(-1));})
    ;

blockStatement
    :   {T.pushTop();T.setCurrentParent(T.addNode("localVariableDeclarationStatement"));} t129=localVariableDeclarationStatement {T.popTop().setTextRange($t129.start, $t129.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("classOrInterfaceDeclaration"));} t130=classOrInterfaceDeclaration {T.popTop().setTextRange($t130.start, $t130.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("statement"));} t131=statement {T.popTop().setTextRange($t131.start, $t131.stop);}
    ;


localVariableDeclarationStatement 
    :   {T.pushTop();T.setCurrentParent(T.addNode("localVariableDeclaration"));} t132=localVariableDeclaration {T.popTop().setTextRange($t132.start, $t132.stop);}
        (';'{T.addLeaf("';'",input.LT(-1));})
    ;

localVariableDeclaration 
    :   {T.pushTop();T.setCurrentParent(T.addNode("variableModifiers"));} t133=variableModifiers {T.popTop().setTextRange($t133.start, $t133.stop);} {T.pushTop();T.setCurrentParent(T.addNode("type"));} t134=type {T.popTop().setTextRange($t134.start, $t134.stop);}
        {T.pushTop();T.setCurrentParent(T.addNode("variableDeclarator"));} t135=variableDeclarator {T.popTop().setTextRange($t135.start, $t135.stop);}
        ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("variableDeclarator"));} t136=variableDeclarator {T.popTop().setTextRange($t136.start, $t136.stop);}
        )*
    ;

statement 
    :   {T.pushTop();T.setCurrentParent(T.addNode("block"));} t137=block {T.popTop().setTextRange($t137.start, $t137.stop);}
            
    |   ('assert'{T.addLeaf("'assert'",input.LT(-1));}
        )
        {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t138=expression {T.popTop().setTextRange($t138.start, $t138.stop);} ((':'{T.addLeaf("':'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t139=expression {T.popTop().setTextRange($t139.start, $t139.stop);})? (';'{T.addLeaf("';'",input.LT(-1));})
    |   'assert'{T.addLeaf("'assert'",input.LT(-1));}  {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t140=expression {T.popTop().setTextRange($t140.start, $t140.stop);} ((':'{T.addLeaf("':'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t141=expression {T.popTop().setTextRange($t141.start, $t141.stop);})? (';'{T.addLeaf("';'",input.LT(-1));})            
    |   'if'{T.addLeaf("'if'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("parExpression"));} t142=parExpression {T.popTop().setTextRange($t142.start, $t142.stop);} {T.pushTop();T.setCurrentParent(T.addNode("statement"));} t143=statement {T.popTop().setTextRange($t143.start, $t143.stop);} ('else'{T.addLeaf("'else'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("statement"));} t144=statement {T.popTop().setTextRange($t144.start, $t144.stop);})?          
    |   {T.pushTop();T.setCurrentParent(T.addNode("forstatement"));} t145=forstatement {T.popTop().setTextRange($t145.start, $t145.stop);}
    |   'while'{T.addLeaf("'while'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("parExpression"));} t146=parExpression {T.popTop().setTextRange($t146.start, $t146.stop);} {T.pushTop();T.setCurrentParent(T.addNode("statement"));} t147=statement {T.popTop().setTextRange($t147.start, $t147.stop);}
    |   'do'{T.addLeaf("'do'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("statement"));} t148=statement {T.popTop().setTextRange($t148.start, $t148.stop);} 'while'{T.addLeaf("'while'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("parExpression"));} t149=parExpression {T.popTop().setTextRange($t149.start, $t149.stop);} (';'{T.addLeaf("';'",input.LT(-1));})
    |   {T.pushTop();T.setCurrentParent(T.addNode("trystatement"));} t150=trystatement {T.popTop().setTextRange($t150.start, $t150.stop);}
    |   'switch'{T.addLeaf("'switch'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("parExpression"));} t151=parExpression {T.popTop().setTextRange($t151.start, $t151.stop);} ('{'{T.addLeaf("'{'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("switchBlockStatementGroups"));} t152=switchBlockStatementGroups {T.popTop().setTextRange($t152.start, $t152.stop);} ('}'{T.addLeaf("'}'",input.LT(-1));})
    |   'synchronized'{T.addLeaf("'synchronized'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("parExpression"));} t153=parExpression {T.popTop().setTextRange($t153.start, $t153.stop);} {T.pushTop();T.setCurrentParent(T.addNode("block"));} t154=block {T.popTop().setTextRange($t154.start, $t154.stop);}
    |   'return'{T.addLeaf("'return'",input.LT(-1));} ({T.pushTop();T.setCurrentParent(T.addNode("expression"));} t155=expression {T.popTop().setTextRange($t155.start, $t155.stop);} )? (';'{T.addLeaf("';'",input.LT(-1));})
    |   'throw'{T.addLeaf("'throw'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t156=expression {T.popTop().setTextRange($t156.start, $t156.stop);} (';'{T.addLeaf("';'",input.LT(-1));})
    |   'break'{T.addLeaf("'break'",input.LT(-1));}
            (IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
            )? (';'{T.addLeaf("';'",input.LT(-1));})
    |   'continue'{T.addLeaf("'continue'",input.LT(-1));}
            (IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
            )? (';'{T.addLeaf("';'",input.LT(-1));})
    |   {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t157=expression {T.popTop().setTextRange($t157.start, $t157.stop);}  (';'{T.addLeaf("';'",input.LT(-1));})     
    |   IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));} (':'{T.addLeaf("':'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("statement"));} t158=statement {T.popTop().setTextRange($t158.start, $t158.stop);}
    |   (';'{T.addLeaf("';'",input.LT(-1));})

    ;

switchBlockStatementGroups 
    :   ({T.pushTop();T.setCurrentParent(T.addNode("switchBlockStatementGroup"));} t159=switchBlockStatementGroup {T.popTop().setTextRange($t159.start, $t159.stop);} )*
    ;

switchBlockStatementGroup 
    :
        {T.pushTop();T.setCurrentParent(T.addNode("switchLabel"));} t160=switchLabel {T.popTop().setTextRange($t160.start, $t160.stop);}
        ({T.pushTop();T.setCurrentParent(T.addNode("blockStatement"));} t161=blockStatement {T.popTop().setTextRange($t161.start, $t161.stop);}
        )*
    ;

switchLabel 
    :   'case'{T.addLeaf("'case'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t162=expression {T.popTop().setTextRange($t162.start, $t162.stop);} (':'{T.addLeaf("':'",input.LT(-1));})
    |   'default'{T.addLeaf("'default'",input.LT(-1));} (':'{T.addLeaf("':'",input.LT(-1));})
    ;


trystatement 
    :   'try'{T.addLeaf("'try'",input.LT(-1));} ({T.pushTop();T.setCurrentParent(T.addNode("resourceSpecification"));} t163=resourceSpecification {T.popTop().setTextRange($t163.start, $t163.stop);})? {T.pushTop();T.setCurrentParent(T.addNode("block"));} t164=block {T.popTop().setTextRange($t164.start, $t164.stop);}
        (   {T.pushTop();T.setCurrentParent(T.addNode("catches"));} t165=catches {T.popTop().setTextRange($t165.start, $t165.stop);} 'finally'{T.addLeaf("'finally'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("block"));} t166=block {T.popTop().setTextRange($t166.start, $t166.stop);}
        |   {T.pushTop();T.setCurrentParent(T.addNode("catches"));} t167=catches {T.popTop().setTextRange($t167.start, $t167.stop);}
        |   'finally'{T.addLeaf("'finally'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("block"));} t168=block {T.popTop().setTextRange($t168.start, $t168.stop);}
        )?
     ;

resourceSpecification
    :
      ('('{T.addLeaf("'('",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("resources"));} t169=resources {T.popTop().setTextRange($t169.start, $t169.stop);} ((';'{T.addLeaf("';'",input.LT(-1));}))? (')'{T.addLeaf("')'",input.LT(-1));})
    ;

resources
    :
       {T.pushTop();T.setCurrentParent(T.addNode("resource"));} t170=resource {T.popTop().setTextRange($t170.start, $t170.stop);} ( (';'{T.addLeaf("';'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("resource"));} t171=resource {T.popTop().setTextRange($t171.start, $t171.stop);} )*
    ;

resource
    :
      {T.pushTop();T.setCurrentParent(T.addNode("variableModifiers"));} t172=variableModifiers {T.popTop().setTextRange($t172.start, $t172.stop);} {T.pushTop();T.setCurrentParent(T.addNode("classOrInterfaceType"));} t173=classOrInterfaceType {T.popTop().setTextRange($t173.start, $t173.stop);} {T.pushTop();T.setCurrentParent(T.addNode("variableDeclaratorId"));} t174=variableDeclaratorId {T.popTop().setTextRange($t174.start, $t174.stop);} ('='{T.addLeaf("'='",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t175=expression {T.popTop().setTextRange($t175.start, $t175.stop);}
    ;

variableDeclaratorId
    :
        IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));} (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));}))*
    ;

catches
    :   {T.pushTop();T.setCurrentParent(T.addNode("catchClause"));} t176=catchClause {T.popTop().setTextRange($t176.start, $t176.stop);}
        ({T.pushTop();T.setCurrentParent(T.addNode("catchClause"));} t177=catchClause {T.popTop().setTextRange($t177.start, $t177.stop);}
        )*
    ;

catchClause 
    :   'catch'{T.addLeaf("'catch'",input.LT(-1));} ('('{T.addLeaf("'('",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("formalParameter"));} t178=formalParameter {T.popTop().setTextRange($t178.start, $t178.stop);}
        (')'{T.addLeaf("')'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("block"));} t179=block {T.popTop().setTextRange($t179.start, $t179.stop);} 
    ;

formalParameter 
    :   {T.pushTop();T.setCurrentParent(T.addNode("variableModifiers"));} t180=variableModifiers {T.popTop().setTextRange($t180.start, $t180.stop);} {T.pushTop();T.setCurrentParent(T.addNode("catchType"));} t181=catchType {T.popTop().setTextRange($t181.start, $t181.stop);} IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));})
        )*
    ;

catchType
    :  {T.pushTop();T.setCurrentParent(T.addNode("classOrInterfaceType"));} t182=classOrInterfaceType {T.popTop().setTextRange($t182.start, $t182.stop);} ( ('|'{T.addLeaf("'|'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("classOrInterfaceType"));} t183=classOrInterfaceType {T.popTop().setTextRange($t183.start, $t183.stop);} )*
    ;

forstatement
    :   
        // enhanced for loop
        'for'{T.addLeaf("'for'",input.LT(-1));} ('('{T.addLeaf("'('",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("variableModifiers"));} t184=variableModifiers {T.popTop().setTextRange($t184.start, $t184.stop);} {T.pushTop();T.setCurrentParent(T.addNode("type"));} t185=type {T.popTop().setTextRange($t185.start, $t185.stop);} IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));} (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));}))* (':'{T.addLeaf("':'",input.LT(-1));})
        {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t186=expression {T.popTop().setTextRange($t186.start, $t186.stop);} (')'{T.addLeaf("')'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("statement"));} t187=statement {T.popTop().setTextRange($t187.start, $t187.stop);}
            
        // normal for loop
    |   'for'{T.addLeaf("'for'",input.LT(-1));} ('('{T.addLeaf("'('",input.LT(-1));}) 
                ({T.pushTop();T.setCurrentParent(T.addNode("forInit"));} t188=forInit {T.popTop().setTextRange($t188.start, $t188.stop);}
                )? (';'{T.addLeaf("';'",input.LT(-1));}) 
                ({T.pushTop();T.setCurrentParent(T.addNode("expression"));} t189=expression {T.popTop().setTextRange($t189.start, $t189.stop);}
                )? (';'{T.addLeaf("';'",input.LT(-1));}) 
                ({T.pushTop();T.setCurrentParent(T.addNode("expressionList"));} t190=expressionList {T.popTop().setTextRange($t190.start, $t190.stop);}
                )? (')'{T.addLeaf("')'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("statement"));} t191=statement {T.popTop().setTextRange($t191.start, $t191.stop);}
    ;

forInit 
    :   {T.pushTop();T.setCurrentParent(T.addNode("localVariableDeclaration"));} t192=localVariableDeclaration {T.popTop().setTextRange($t192.start, $t192.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("expressionList"));} t193=expressionList {T.popTop().setTextRange($t193.start, $t193.stop);}
    ;

parExpression 
    :   ('('{T.addLeaf("'('",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t194=expression {T.popTop().setTextRange($t194.start, $t194.stop);} (')'{T.addLeaf("')'",input.LT(-1));})
    ;

expressionList 
    :   {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t195=expression {T.popTop().setTextRange($t195.start, $t195.stop);}
        ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t196=expression {T.popTop().setTextRange($t196.start, $t196.stop);}
        )*
    ;


expression 
    :   {T.pushTop();T.setCurrentParent(T.addNode("conditionalExpression"));} t197=conditionalExpression {T.popTop().setTextRange($t197.start, $t197.stop);}
        ({T.pushTop();T.setCurrentParent(T.addNode("assignmentOperator"));} t198=assignmentOperator {T.popTop().setTextRange($t198.start, $t198.stop);} {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t199=expression {T.popTop().setTextRange($t199.start, $t199.stop);}
        )?
    ;


assignmentOperator 
    :   ('='{T.addLeaf("'='",input.LT(-1));})
    |   '+='{T.addLeaf("'+='",input.LT(-1));}
    |   '-='{T.addLeaf("'-='",input.LT(-1));}
    |   '*='{T.addLeaf("'*='",input.LT(-1));}
    |   '/='{T.addLeaf("'/='",input.LT(-1));}
    |   '&='{T.addLeaf("'&='",input.LT(-1));}
    |   '|='{T.addLeaf("'|='",input.LT(-1));}
    |   '^='{T.addLeaf("'^='",input.LT(-1));}
    |   '%='{T.addLeaf("'\%='",input.LT(-1));}
    |    ('<'{T.addLeaf("'<'",input.LT(-1));}) ('<'{T.addLeaf("'<'",input.LT(-1));}) ('='{T.addLeaf("'='",input.LT(-1));})
    |    ('>'{T.addLeaf("'>'",input.LT(-1));}) ('>'{T.addLeaf("'>'",input.LT(-1));}) ('>'{T.addLeaf("'>'",input.LT(-1));}) ('='{T.addLeaf("'='",input.LT(-1));})
    |    ('>'{T.addLeaf("'>'",input.LT(-1));}) ('>'{T.addLeaf("'>'",input.LT(-1));}) ('='{T.addLeaf("'='",input.LT(-1));})
    ;


conditionalExpression 
    :   {T.pushTop();T.setCurrentParent(T.addNode("conditionalOrExpression"));} t200=conditionalOrExpression {T.popTop().setTextRange($t200.start, $t200.stop);}
        (('?'{T.addLeaf("'?'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t201=expression {T.popTop().setTextRange($t201.start, $t201.stop);} (':'{T.addLeaf("':'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("conditionalExpression"));} t202=conditionalExpression {T.popTop().setTextRange($t202.start, $t202.stop);}
        )?
    ;

conditionalOrExpression 
    :   {T.pushTop();T.setCurrentParent(T.addNode("conditionalAndExpression"));} t203=conditionalAndExpression {T.popTop().setTextRange($t203.start, $t203.stop);}
        ('||'{T.addLeaf("'||'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("conditionalAndExpression"));} t204=conditionalAndExpression {T.popTop().setTextRange($t204.start, $t204.stop);}
        )*
    ;

conditionalAndExpression 
    :   {T.pushTop();T.setCurrentParent(T.addNode("inclusiveOrExpression"));} t205=inclusiveOrExpression {T.popTop().setTextRange($t205.start, $t205.stop);}
        ('&&'{T.addLeaf("'&&'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("inclusiveOrExpression"));} t206=inclusiveOrExpression {T.popTop().setTextRange($t206.start, $t206.stop);}
        )*
    ;

inclusiveOrExpression 
    :   {T.pushTop();T.setCurrentParent(T.addNode("exclusiveOrExpression"));} t207=exclusiveOrExpression {T.popTop().setTextRange($t207.start, $t207.stop);}
        (('|'{T.addLeaf("'|'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("exclusiveOrExpression"));} t208=exclusiveOrExpression {T.popTop().setTextRange($t208.start, $t208.stop);}
        )*
    ;

exclusiveOrExpression 
    :   {T.pushTop();T.setCurrentParent(T.addNode("andExpression"));} t209=andExpression {T.popTop().setTextRange($t209.start, $t209.stop);}
        (('^'{T.addLeaf("'^'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("andExpression"));} t210=andExpression {T.popTop().setTextRange($t210.start, $t210.stop);}
        )*
    ;

andExpression 
    :   {T.pushTop();T.setCurrentParent(T.addNode("equalityExpression"));} t211=equalityExpression {T.popTop().setTextRange($t211.start, $t211.stop);}
        (('&'{T.addLeaf("'&'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("equalityExpression"));} t212=equalityExpression {T.popTop().setTextRange($t212.start, $t212.stop);}
        )*
    ;

equalityExpression 
    :   {T.pushTop();T.setCurrentParent(T.addNode("instanceOfExpression"));} t213=instanceOfExpression {T.popTop().setTextRange($t213.start, $t213.stop);}
        (   
            (   '=='{T.addLeaf("'=='",input.LT(-1));}
            |   '!='{T.addLeaf("'!='",input.LT(-1));}
            )
            {T.pushTop();T.setCurrentParent(T.addNode("instanceOfExpression"));} t214=instanceOfExpression {T.popTop().setTextRange($t214.start, $t214.stop);}
        )*
    ;

instanceOfExpression 
    :   {T.pushTop();T.setCurrentParent(T.addNode("relationalExpression"));} t215=relationalExpression {T.popTop().setTextRange($t215.start, $t215.stop);}
        ('instanceof'{T.addLeaf("'instanceof'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("type"));} t216=type {T.popTop().setTextRange($t216.start, $t216.stop);}
        )?
    ;

relationalExpression 
    :   {T.pushTop();T.setCurrentParent(T.addNode("shiftExpression"));} t217=shiftExpression {T.popTop().setTextRange($t217.start, $t217.stop);}
        ({T.pushTop();T.setCurrentParent(T.addNode("relationalOp"));} t218=relationalOp {T.popTop().setTextRange($t218.start, $t218.stop);} {T.pushTop();T.setCurrentParent(T.addNode("shiftExpression"));} t219=shiftExpression {T.popTop().setTextRange($t219.start, $t219.stop);}
        )*
    ;

relationalOp 
    :    ('<'{T.addLeaf("'<'",input.LT(-1));}) ('='{T.addLeaf("'='",input.LT(-1));})
    |    ('>'{T.addLeaf("'>'",input.LT(-1));}) ('='{T.addLeaf("'='",input.LT(-1));})
    |   ('<'{T.addLeaf("'<'",input.LT(-1));})
    |   ('>'{T.addLeaf("'>'",input.LT(-1));})
    ;

shiftExpression 
    :   {T.pushTop();T.setCurrentParent(T.addNode("additiveExpression"));} t220=additiveExpression {T.popTop().setTextRange($t220.start, $t220.stop);}
        ({T.pushTop();T.setCurrentParent(T.addNode("shiftOp"));} t221=shiftOp {T.popTop().setTextRange($t221.start, $t221.stop);} {T.pushTop();T.setCurrentParent(T.addNode("additiveExpression"));} t222=additiveExpression {T.popTop().setTextRange($t222.start, $t222.stop);}
        )*
    ;


shiftOp 
    :    ('<'{T.addLeaf("'<'",input.LT(-1));}) ('<'{T.addLeaf("'<'",input.LT(-1));})
    |    ('>'{T.addLeaf("'>'",input.LT(-1));}) ('>'{T.addLeaf("'>'",input.LT(-1));}) ('>'{T.addLeaf("'>'",input.LT(-1));})
    |    ('>'{T.addLeaf("'>'",input.LT(-1));}) ('>'{T.addLeaf("'>'",input.LT(-1));})
    ;


additiveExpression 
    :   {T.pushTop();T.setCurrentParent(T.addNode("multiplicativeExpression"));} t223=multiplicativeExpression {T.popTop().setTextRange($t223.start, $t223.stop);}
        (   
            (   ('+'{T.addLeaf("'+'",input.LT(-1));})
            |   ('-'{T.addLeaf("'-'",input.LT(-1));})
            )
            {T.pushTop();T.setCurrentParent(T.addNode("multiplicativeExpression"));} t224=multiplicativeExpression {T.popTop().setTextRange($t224.start, $t224.stop);}
         )*
    ;

multiplicativeExpression 
    :
        {T.pushTop();T.setCurrentParent(T.addNode("unaryExpression"));} t225=unaryExpression {T.popTop().setTextRange($t225.start, $t225.stop);}
        (   
            (   ('*'{T.addLeaf("'*'",input.LT(-1));})
            |   ('/'{T.addLeaf("'/'",input.LT(-1));})
            |   ('%'{T.addLeaf("'\%'",input.LT(-1));})
            )
            {T.pushTop();T.setCurrentParent(T.addNode("unaryExpression"));} t226=unaryExpression {T.popTop().setTextRange($t226.start, $t226.stop);}
        )*
    ;

/**
 * NOTE: for '+' and '-', if the next token is int or long interal, then it's not a unary expression.
 *       it's a literal with signed value. INTLTERAL AND LONG LITERAL are added here for this.
 */
unaryExpression 
    :   ('+'{T.addLeaf("'+'",input.LT(-1));})  {T.pushTop();T.setCurrentParent(T.addNode("unaryExpression"));} t227=unaryExpression {T.popTop().setTextRange($t227.start, $t227.stop);}
    |   ('-'{T.addLeaf("'-'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("unaryExpression"));} t228=unaryExpression {T.popTop().setTextRange($t228.start, $t228.stop);}
    |   '++'{T.addLeaf("'++'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("unaryExpression"));} t229=unaryExpression {T.popTop().setTextRange($t229.start, $t229.stop);}
    |   '--'{T.addLeaf("'--'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("unaryExpression"));} t230=unaryExpression {T.popTop().setTextRange($t230.start, $t230.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("unaryExpressionNotPlusMinus"));} t231=unaryExpressionNotPlusMinus {T.popTop().setTextRange($t231.start, $t231.stop);}
    ;

unaryExpressionNotPlusMinus 
    :   ('~'{T.addLeaf("'~'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("unaryExpression"));} t232=unaryExpression {T.popTop().setTextRange($t232.start, $t232.stop);}
    |   ('!'{T.addLeaf("'!'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("unaryExpression"));} t233=unaryExpression {T.popTop().setTextRange($t233.start, $t233.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("castExpression"));} t234=castExpression {T.popTop().setTextRange($t234.start, $t234.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("primary"));} t235=primary {T.popTop().setTextRange($t235.start, $t235.stop);}
        ({T.pushTop();T.setCurrentParent(T.addNode("selector"));} t236=selector {T.popTop().setTextRange($t236.start, $t236.stop);}
        )*
        (   '++'{T.addLeaf("'++'",input.LT(-1));}
        |   '--'{T.addLeaf("'--'",input.LT(-1));}
        )?
    ;

castExpression 
    :   ('('{T.addLeaf("'('",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("primitiveType"));} t237=primitiveType {T.popTop().setTextRange($t237.start, $t237.stop);} (')'{T.addLeaf("')'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("unaryExpression"));} t238=unaryExpression {T.popTop().setTextRange($t238.start, $t238.stop);}
    |   ('('{T.addLeaf("'('",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("type"));} t239=type {T.popTop().setTextRange($t239.start, $t239.stop);} (')'{T.addLeaf("')'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("unaryExpressionNotPlusMinus"));} t240=unaryExpressionNotPlusMinus {T.popTop().setTextRange($t240.start, $t240.stop);}
    ;

/**
 * have to use scope here, parameter passing isn't well supported in antlr.
 */
primary 
    :   {T.pushTop();T.setCurrentParent(T.addNode("parExpression"));} t241=parExpression {T.popTop().setTextRange($t241.start, $t241.stop);}            
    |   'this'{T.addLeaf("'this'",input.LT(-1));}
        (('.'{T.addLeaf("'.'",input.LT(-1));}) IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        )*
        ({T.pushTop();T.setCurrentParent(T.addNode("identifierSuffix"));} t242=identifierSuffix {T.popTop().setTextRange($t242.start, $t242.stop);}
        )?
    |   IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        (('.'{T.addLeaf("'.'",input.LT(-1));}) IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        )*
        ({T.pushTop();T.setCurrentParent(T.addNode("identifierSuffix"));} t243=identifierSuffix {T.popTop().setTextRange($t243.start, $t243.stop);}
        )?
    |   'super'{T.addLeaf("'super'",input.LT(-1));}
        {T.pushTop();T.setCurrentParent(T.addNode("superSuffix"));} t244=superSuffix {T.popTop().setTextRange($t244.start, $t244.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("literal"));} t245=literal {T.popTop().setTextRange($t245.start, $t245.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("creator"));} t246=creator {T.popTop().setTextRange($t246.start, $t246.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("primitiveType"));} t247=primitiveType {T.popTop().setTextRange($t247.start, $t247.stop);}
        (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));})
        )*
        ('.'{T.addLeaf("'.'",input.LT(-1));}) 'class'{T.addLeaf("'class'",input.LT(-1));}
    |   'void'{T.addLeaf("'void'",input.LT(-1));} ('.'{T.addLeaf("'.'",input.LT(-1));}) 'class'{T.addLeaf("'class'",input.LT(-1));}
    ;
    

superSuffix  
    :   {T.pushTop();T.setCurrentParent(T.addNode("arguments"));} t248=arguments {T.popTop().setTextRange($t248.start, $t248.stop);}
    |   ('.'{T.addLeaf("'.'",input.LT(-1));}) ({T.pushTop();T.setCurrentParent(T.addNode("typeArguments"));} t249=typeArguments {T.popTop().setTextRange($t249.start, $t249.stop);}
        )?
        IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        ({T.pushTop();T.setCurrentParent(T.addNode("arguments"));} t250=arguments {T.popTop().setTextRange($t250.start, $t250.stop);}
        )?
    ;


identifierSuffix 
    :   (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));})
        )+
        ('.'{T.addLeaf("'.'",input.LT(-1));}) 'class'{T.addLeaf("'class'",input.LT(-1));}
    |   (('['{T.addLeaf("'['",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t251=expression {T.popTop().setTextRange($t251.start, $t251.stop);} (']'{T.addLeaf("']'",input.LT(-1));})
        )+
    |   {T.pushTop();T.setCurrentParent(T.addNode("arguments"));} t252=arguments {T.popTop().setTextRange($t252.start, $t252.stop);}
    |   ('.'{T.addLeaf("'.'",input.LT(-1));}) 'class'{T.addLeaf("'class'",input.LT(-1));}
    |   ('.'{T.addLeaf("'.'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("nonWildcardTypeArguments"));} t253=nonWildcardTypeArguments {T.popTop().setTextRange($t253.start, $t253.stop);} IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("arguments"));} t254=arguments {T.popTop().setTextRange($t254.start, $t254.stop);}
    |   ('.'{T.addLeaf("'.'",input.LT(-1));}) 'this'{T.addLeaf("'this'",input.LT(-1));}
    |   ('.'{T.addLeaf("'.'",input.LT(-1));}) 'super'{T.addLeaf("'super'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("arguments"));} t255=arguments {T.popTop().setTextRange($t255.start, $t255.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("innerCreator"));} t256=innerCreator {T.popTop().setTextRange($t256.start, $t256.stop);}
    ;


selector  
    :   ('.'{T.addLeaf("'.'",input.LT(-1));}) IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        ({T.pushTop();T.setCurrentParent(T.addNode("arguments"));} t257=arguments {T.popTop().setTextRange($t257.start, $t257.stop);}
        )?
    | ('.'{T.addLeaf("'.'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("nonWildcardTypeArguments"));} t258=nonWildcardTypeArguments {T.popTop().setTextRange($t258.start, $t258.stop);} IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("arguments"));} t259=arguments {T.popTop().setTextRange($t259.start, $t259.stop);}
    |   ('.'{T.addLeaf("'.'",input.LT(-1));}) 'this'{T.addLeaf("'this'",input.LT(-1));}
    |   ('.'{T.addLeaf("'.'",input.LT(-1));}) 'super'{T.addLeaf("'super'",input.LT(-1));}
        {T.pushTop();T.setCurrentParent(T.addNode("superSuffix"));} t260=superSuffix {T.popTop().setTextRange($t260.start, $t260.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("innerCreator"));} t261=innerCreator {T.popTop().setTextRange($t261.start, $t261.stop);}
    |   ('['{T.addLeaf("'['",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t262=expression {T.popTop().setTextRange($t262.start, $t262.stop);} (']'{T.addLeaf("']'",input.LT(-1));})
    ;


typeArgumentsOrDiamond
   :
      ('<'{T.addLeaf("'<'",input.LT(-1));}) ('>'{T.addLeaf("'>'",input.LT(-1));})
    | {T.pushTop();T.setCurrentParent(T.addNode("typeArguments"));} t263=typeArguments {T.popTop().setTextRange($t263.start, $t263.stop);}
    ;

nonWildcardTypeArgumentsOrDiamond
   :
      ('<'{T.addLeaf("'<'",input.LT(-1));}) ('>'{T.addLeaf("'>'",input.LT(-1));})
    | {T.pushTop();T.setCurrentParent(T.addNode("nonWildcardTypeArguments"));} t264=nonWildcardTypeArguments {T.popTop().setTextRange($t264.start, $t264.stop);}
    ;

creator
    :   'new'{T.addLeaf("'new'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("nonWildcardTypeArguments"));} t265=nonWildcardTypeArguments {T.popTop().setTextRange($t265.start, $t265.stop);} {T.pushTop();T.setCurrentParent(T.addNode("classOrInterfaceType"));} t266=classOrInterfaceType {T.popTop().setTextRange($t266.start, $t266.stop);} {T.pushTop();T.setCurrentParent(T.addNode("classCreatorRest"));} t267=classCreatorRest {T.popTop().setTextRange($t267.start, $t267.stop);}
    |   'new'{T.addLeaf("'new'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("classOrInterfaceType"));} t268=classOrInterfaceType {T.popTop().setTextRange($t268.start, $t268.stop);} {T.pushTop();T.setCurrentParent(T.addNode("classCreatorRest"));} t269=classCreatorRest {T.popTop().setTextRange($t269.start, $t269.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("arrayCreator"));} t270=arrayCreator {T.popTop().setTextRange($t270.start, $t270.stop);}
    ;

arrayCreator 
    :   'new'{T.addLeaf("'new'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("createdName"));} t271=createdName {T.popTop().setTextRange($t271.start, $t271.stop);}
        ('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));})
        (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));})
        )*
        {T.pushTop();T.setCurrentParent(T.addNode("arrayInitializer"));} t272=arrayInitializer {T.popTop().setTextRange($t272.start, $t272.stop);}

    |   'new'{T.addLeaf("'new'",input.LT(-1));} {T.pushTop();T.setCurrentParent(T.addNode("createdName"));} t273=createdName {T.popTop().setTextRange($t273.start, $t273.stop);}
        ('['{T.addLeaf("'['",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t274=expression {T.popTop().setTextRange($t274.start, $t274.stop);}
        (']'{T.addLeaf("']'",input.LT(-1));})
        (   ('['{T.addLeaf("'['",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t275=expression {T.popTop().setTextRange($t275.start, $t275.stop);}
            (']'{T.addLeaf("']'",input.LT(-1));})
        )*
        (('['{T.addLeaf("'['",input.LT(-1));}) (']'{T.addLeaf("']'",input.LT(-1));})
        )*
    ;

variableInitializer 
    :   {T.pushTop();T.setCurrentParent(T.addNode("arrayInitializer"));} t276=arrayInitializer {T.popTop().setTextRange($t276.start, $t276.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("expression"));} t277=expression {T.popTop().setTextRange($t277.start, $t277.stop);}
    ;

arrayInitializer 
    :   ('{'{T.addLeaf("'{'",input.LT(-1));}) 
            ({T.pushTop();T.setCurrentParent(T.addNode("variableInitializer"));} t278=variableInitializer {T.popTop().setTextRange($t278.start, $t278.stop);}
                ((','{T.addLeaf("','",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("variableInitializer"));} t279=variableInitializer {T.popTop().setTextRange($t279.start, $t279.stop);}
                )*
            )? 
            ((','{T.addLeaf("','",input.LT(-1));}))? 
        ('}'{T.addLeaf("'}'",input.LT(-1));})             //Yang's fix, position change.
    ;


createdName 
    :   {T.pushTop();T.setCurrentParent(T.addNode("classOrInterfaceType"));} t280=classOrInterfaceType {T.popTop().setTextRange($t280.start, $t280.stop);}
    |   {T.pushTop();T.setCurrentParent(T.addNode("primitiveType"));} t281=primitiveType {T.popTop().setTextRange($t281.start, $t281.stop);}
    ;

innerCreator  
    :   ('.'{T.addLeaf("'.'",input.LT(-1));}) 'new'{T.addLeaf("'new'",input.LT(-1));}
        ({T.pushTop();T.setCurrentParent(T.addNode("nonWildcardTypeArguments"));} t282=nonWildcardTypeArguments {T.popTop().setTextRange($t282.start, $t282.stop);}
        )?
        IDENTIFIER {T.addLeaf("IDENTIFIER['"+input.LT(-1).getText()+"']",input.LT(-1));}
        ({T.pushTop();T.setCurrentParent(T.addNode("nonWildcardTypeArgumentsOrDiamond"));} t283=nonWildcardTypeArgumentsOrDiamond {T.popTop().setTextRange($t283.start, $t283.stop);}
        )?
        {T.pushTop();T.setCurrentParent(T.addNode("classCreatorRest"));} t284=classCreatorRest {T.popTop().setTextRange($t284.start, $t284.stop);}
    ;


classCreatorRest 
    :   {T.pushTop();T.setCurrentParent(T.addNode("arguments"));} t285=arguments {T.popTop().setTextRange($t285.start, $t285.stop);}
        ({T.pushTop();T.setCurrentParent(T.addNode("classBody"));} t286=classBody {T.popTop().setTextRange($t286.start, $t286.stop);}
        )?
    ;


nonWildcardTypeArguments 
    :   ('<'{T.addLeaf("'<'",input.LT(-1));}) {T.pushTop();T.setCurrentParent(T.addNode("typeList"));} t287=typeList {T.popTop().setTextRange($t287.start, $t287.stop);}
        ('>'{T.addLeaf("'>'",input.LT(-1));})
    ;

arguments 
    :   ('('{T.addLeaf("'('",input.LT(-1));}) ({T.pushTop();T.setCurrentParent(T.addNode("expressionList"));} t288=expressionList {T.popTop().setTextRange($t288.start, $t288.stop);}
        )? (')'{T.addLeaf("')'",input.LT(-1));})
    ;

literal 
    :   INTLITERAL {T.addLeaf("INTLITERAL['"+input.LT(-1).getText()+"']",input.LT(-1));}
    |   LONGLITERAL {T.addLeaf("LONGLITERAL['"+input.LT(-1).getText()+"']",input.LT(-1));}
    |   BINLITERAL {T.addLeaf("BINLITERAL['"+input.LT(-1).getText()+"']",input.LT(-1));}
    |   FLOATLITERAL {T.addLeaf("FLOATLITERAL['"+input.LT(-1).getText()+"']",input.LT(-1));}
    |   DOUBLELITERAL {T.addLeaf("DOUBLELITERAL['"+input.LT(-1).getText()+"']",input.LT(-1));}
    |   CHARLITERAL {T.addLeaf("CHARLITERAL['"+input.LT(-1).getText()+"']",input.LT(-1));}
    |   STRINGLITERAL {T.addLeaf("STRINGLITERAL['"+input.LT(-1).getText()+"']",input.LT(-1));}
    |   TRUE {T.addLeaf("TRUE['"+input.LT(-1).getText()+"']",input.LT(-1));}
    |   FALSE {T.addLeaf("FALSE['"+input.LT(-1).getText()+"']",input.LT(-1));}
    |   NULL {T.addLeaf("NULL['"+input.LT(-1).getText()+"']",input.LT(-1));}
    ;



/********************************************************************************************
                  Lexer Section
*********************************************************************************************/

LONGLITERAL
    :   IntegerNumber LongSuffix
    ;

    
INTLITERAL
    :   IntegerNumber 
    ;
    
BINLITERAL
    :
      BinPrefix ('0'|'1') (('0'|'1'|'_')* ('0'|'1'))? LongSuffix?
    ;

fragment
BinPrefix
    :   '0b' | '0B'
    ;

fragment
IntegerNumber
    :   '0' 
    |   '1'..'9' (('0'..'9'|'_')* ('0'..'9'))?
    |   '0' ('0'..'7')  (('0'..'7'|'_')* ('0'..'7'))?
    |   HexNumber
    ;

fragment
HexNumber
    : HexPrefix HexDigit ((HexDigit | '_')* HexDigit)?
    ;

fragment
HexPrefix
    :   '0x' | '0X'
    ;
        
fragment
HexDigit
    :   ('0'..'9'|'a'..'f'|'A'..'F')
    ;

fragment
LongSuffix
    :   'l' | 'L'
    ;


fragment
NonIntegerNumber
    :   ('0' .. '9') (('0'..'9'|'_')* ('0'..'9'))? '.' ('0'..'9' (('0'..'9'|'_')* ('0'..'9'))?)? Exponent?
    |   '.' ('0' .. '9') (('0'..'9'|'_')* ('0'..'9'))? Exponent?
    |   ('0' .. '9') (('0'..'9'|'_')* ('0'..'9'))? Exponent
    |   ('0' .. '9') (('0'..'9'|'_')* ('0'..'9'))?
    |   
        (
            HexPrefix (HexDigit ((HexDigit | '_')* HexDigit)?)? (
                                                                   ('.' (HexDigit ((HexDigit | '_')* HexDigit)?)?)
                                                                   | ()
        ) 
        ( 'p' | 'P' ) 
        ( '+' | '-' )? 
            ('0' .. '9') (('0'..'9'|'_')* ('0'..'9'))?
        )
        ;
        
fragment 
Exponent    
    :   ( 'e' | 'E' ) ( '+' | '-' )? ('0' .. '9') (('0'..'9'|'_')* ('0'..'9'))?
    ;
    
fragment 
FloatSuffix
    :   'f' | 'F' 
    ;     

fragment
DoubleSuffix
    :   'd' | 'D'
    ;
        
FLOATLITERAL
    :   NonIntegerNumber FloatSuffix
    ;
    
DOUBLELITERAL
    :   NonIntegerNumber DoubleSuffix?
    ;

CHARLITERAL
    :   '\'' 
        (   EscapeSequence 
        |   ~( '\'' | '\\' | '\r' | '\n' )
        ) 
        '\''
    ; 

STRINGLITERAL
    :   '"' 
        (   EscapeSequence
        |   ~( '\\' | '"' | '\r' | '\n' )        
        )* 
        '"' 
    ;

fragment
EscapeSequence 
    :   '\\' (
                 'b' 
             |   't' 
             |   'n' 
             |   'f' 
             |   'r' 
             |   'u'+  HexDigit HexDigit HexDigit HexDigit
             |   '\"'
             |   '\''
             |   '\\'
             |       
                 ('0'..'3') ('0'..'7') ('0'..'7')
             |       
                 ('0'..'7') ('0'..'7') 
             |       
                 ('0'..'7')
             )          
;     

WS  
    :   (
             ' '
        |    '\r'
        |    '\t'
        |    '\u000C'
        |    '\n'
        ) 
            {
                skip();
            }          
    ;
    
COMMENT
         @init{
            boolean isJavaDoc = false;
        }
    :   '/*'
            {
                if((char)input.LA(1) == '*'){
                    isJavaDoc = true;
                }
            }
        (options {greedy=false;} : . )* 
        '*/'
            {
                if(isJavaDoc==true){
                    $channel=HIDDEN;
                }else{
                    skip();
                }
            }
    ;

LINE_COMMENT
    :   '//' ~('\n'|'\r')*  ('\r\n' | '\r' | '\n') 
            {
                skip();
            }
    |   '//' ~('\n'|'\r')*     // a line comment could appear at the end of the file without CR/LF
            {
                skip();
            }
    ;   
        
ABSTRACT
    :   'abstract'
    ;
    
ASSERT
    :   'assert'
    ;
    
BOOLEAN
    :   'boolean'
    ;
    
BREAK
    :   'break'
    ;
    
BYTE
    :   'byte'
    ;
    
CASE
    :   'case'
    ;
    
CATCH
    :   'catch'
    ;
    
CHAR
    :   'char'
    ;
    
CLASS
    :   'class'
    ;
    
CONST
    :   'const'
    ;

CONTINUE
    :   'continue'
    ;

DEFAULT
    :   'default'
    ;

DO
    :   'do'
    ;

DOUBLE
    :   'double'
    ;

ELSE
    :   'else'
    ;

ENUM
    :   'enum'
    ;             

EXTENDS
    :   'extends'
    ;

FINAL
    :   'final'
    ;

FINALLY
    :   'finally'
    ;

FLOAT
    :   'float'
    ;

FOR
    :   'for'
    ;

GOTO
    :   'goto'
    ;

IF
    :   'if'
    ;

IMPLEMENTS
    :   'implements'
    ;

IMPORT
    :   'import'
    ;

INSTANCEOF
    :   'instanceof'
    ;

INT
    :   'int'
    ;

INTERFACE
    :   'interface'
    ;

LONG
    :   'long'
    ;

NATIVE
    :   'native'
    ;

NEW
    :   'new'
    ;

PACKAGE
    :   'package'
    ;

PRIVATE
    :   'private'
    ;

PROTECTED
    :   'protected'
    ;

PUBLIC
    :   'public'
    ;

RETURN
    :   'return'
    ;

SHORT
    :   'short'
    ;

STATIC
    :   'static'
    ;

STRICTFP
    :   'strictfp'
    ;

SUPER
    :   'super'
    ;

SWITCH
    :   'switch'
    ;

SYNCHRONIZED
    :   'synchronized'
    ;

THIS
    :   'this'
    ;

THROW
    :   'throw'
    ;

THROWS
    :   'throws'
    ;

TRANSIENT
    :   'transient'
    ;

TRY
    :   'try'
    ;

VOID
    :   'void'
    ;

VOLATILE
    :   'volatile'
    ;

WHILE
    :   'while'
    ;

TRUE
    :   'true'
    ;

FALSE
    :   'false'
    ;

NULL
    :   'null'
    ;

LPAREN
    :   '('
    ;

RPAREN
    :   ')'
    ;

LBRACE
    :   '{'
    ;

RBRACE
    :   '}'
    ;

LBRACKET
    :   '['
    ;

RBRACKET
    :   ']'
    ;

SEMI
    :   ';'
    ;

COMMA
    :   ','
    ;

DOT
    :   '.'
    ;

ELLIPSIS
    :   '...'
    ;

EQ
    :   '='
    ;

BANG
    :   '!'
    ;

TILDE
    :   '~'
    ;

QUES
    :   '?'
    ;

COLON
    :   ':'
    ;

EQEQ
    :   '=='
    ;

AMPAMP
    :   '&&'
    ;

BARBAR
    :   '||'
    ;

PLUSPLUS
    :   '++'
    ;

SUBSUB
    :   '--'
    ;

PLUS
    :   '+'
    ;

SUB
    :   '-'
    ;

STAR
    :   '*'
    ;

SLASH
    :   '/'
    ;

AMP
    :   '&'
    ;

BAR
    :   '|'
    ;

CARET
    :   '^'
    ;

PERCENT
    :   '%'
    ;

PLUSEQ
    :   '+='
    ; 
    
SUBEQ
    :   '-='
    ;

STAREQ
    :   '*='
    ;

SLASHEQ
    :   '/='
    ;

AMPEQ
    :   '&='
    ;

BAREQ
    :   '|='
    ;

CARETEQ
    :   '^='
    ;

PERCENTEQ
    :   '%='
    ;

MONKEYS_AT
    :   '@'
    ;

BANGEQ
    :   '!='
    ;

GT
    :   '>'
    ;

LT
    :   '<'
    ;        
              
IDENTIFIER
    :   IdentifierStart IdentifierPart*
    ;

fragment
SurrogateIdentifer 
    :   ('\ud800'..'\udbff') ('\udc00'..'\udfff') 
    ;                 

fragment
IdentifierStart
    :   '\u0024'
    |   '\u0041'..'\u005a'
    |   '\u005f'
    |   '\u0061'..'\u007a'
    |   '\u00a2'..'\u00a5'
    |   '\u00aa'
    |   '\u00b5'
    |   '\u00ba'
    |   '\u00c0'..'\u00d6'
    |   '\u00d8'..'\u00f6'
    |   '\u00f8'..'\u0236'
    |   '\u0250'..'\u02c1'
    |   '\u02c6'..'\u02d1'
    |   '\u02e0'..'\u02e4'
    |   '\u02ee'
    |   '\u037a'
    |   '\u0386'
    |   '\u0388'..'\u038a'
    |   '\u038c'
    |   '\u038e'..'\u03a1'
    |   '\u03a3'..'\u03ce'
    |   '\u03d0'..'\u03f5'
    |   '\u03f7'..'\u03fb'
    |   '\u0400'..'\u0481'
    |   '\u048a'..'\u04ce'
    |   '\u04d0'..'\u04f5'
    |   '\u04f8'..'\u04f9'
    |   '\u0500'..'\u050f'
    |   '\u0531'..'\u0556'
    |   '\u0559'
    |   '\u0561'..'\u0587'
    |   '\u05d0'..'\u05ea'
    |   '\u05f0'..'\u05f2'
    |   '\u0621'..'\u063a'
    |   '\u0640'..'\u064a'
    |   '\u066e'..'\u066f'
    |   '\u0671'..'\u06d3'
    |   '\u06d5'
    |   '\u06e5'..'\u06e6'
    |   '\u06ee'..'\u06ef'
    |   '\u06fa'..'\u06fc'
    |   '\u06ff'
    |   '\u0710'
    |   '\u0712'..'\u072f'
    |   '\u074d'..'\u074f'
    |   '\u0780'..'\u07a5'
    |   '\u07b1'
    |   '\u0904'..'\u0939'
    |   '\u093d'
    |   '\u0950'
    |   '\u0958'..'\u0961'
    |   '\u0985'..'\u098c'
    |   '\u098f'..'\u0990'
    |   '\u0993'..'\u09a8'
    |   '\u09aa'..'\u09b0'
    |   '\u09b2'
    |   '\u09b6'..'\u09b9'
    |   '\u09bd'
    |   '\u09dc'..'\u09dd'
    |   '\u09df'..'\u09e1'
    |   '\u09f0'..'\u09f3'
    |   '\u0a05'..'\u0a0a'
    |   '\u0a0f'..'\u0a10'
    |   '\u0a13'..'\u0a28'
    |   '\u0a2a'..'\u0a30'
    |   '\u0a32'..'\u0a33'
    |   '\u0a35'..'\u0a36'
    |   '\u0a38'..'\u0a39'
    |   '\u0a59'..'\u0a5c'
    |   '\u0a5e'
    |   '\u0a72'..'\u0a74'
    |   '\u0a85'..'\u0a8d'
    |   '\u0a8f'..'\u0a91'
    |   '\u0a93'..'\u0aa8'
    |   '\u0aaa'..'\u0ab0'
    |   '\u0ab2'..'\u0ab3'
    |   '\u0ab5'..'\u0ab9'
    |   '\u0abd'
    |   '\u0ad0'
    |   '\u0ae0'..'\u0ae1'
    |   '\u0af1'
    |   '\u0b05'..'\u0b0c'
    |   '\u0b0f'..'\u0b10'
    |   '\u0b13'..'\u0b28'
    |   '\u0b2a'..'\u0b30'
    |   '\u0b32'..'\u0b33'
    |   '\u0b35'..'\u0b39'
    |   '\u0b3d'
    |   '\u0b5c'..'\u0b5d'
    |   '\u0b5f'..'\u0b61'
    |   '\u0b71'
    |   '\u0b83'
    |   '\u0b85'..'\u0b8a'
    |   '\u0b8e'..'\u0b90'
    |   '\u0b92'..'\u0b95'
    |   '\u0b99'..'\u0b9a'
    |   '\u0b9c'
    |   '\u0b9e'..'\u0b9f'
    |   '\u0ba3'..'\u0ba4'
    |   '\u0ba8'..'\u0baa'
    |   '\u0bae'..'\u0bb5'
    |   '\u0bb7'..'\u0bb9'
    |   '\u0bf9'
    |   '\u0c05'..'\u0c0c'
    |   '\u0c0e'..'\u0c10'
    |   '\u0c12'..'\u0c28'
    |   '\u0c2a'..'\u0c33'
    |   '\u0c35'..'\u0c39'
    |   '\u0c60'..'\u0c61'
    |   '\u0c85'..'\u0c8c'
    |   '\u0c8e'..'\u0c90'
    |   '\u0c92'..'\u0ca8'
    |   '\u0caa'..'\u0cb3'
    |   '\u0cb5'..'\u0cb9'
    |   '\u0cbd'
    |   '\u0cde'
    |   '\u0ce0'..'\u0ce1'
    |   '\u0d05'..'\u0d0c'
    |   '\u0d0e'..'\u0d10'
    |   '\u0d12'..'\u0d28'
    |   '\u0d2a'..'\u0d39'
    |   '\u0d60'..'\u0d61'
    |   '\u0d85'..'\u0d96'
    |   '\u0d9a'..'\u0db1'
    |   '\u0db3'..'\u0dbb'
    |   '\u0dbd'
    |   '\u0dc0'..'\u0dc6'
    |   '\u0e01'..'\u0e30'
    |   '\u0e32'..'\u0e33'
    |   '\u0e3f'..'\u0e46'
    |   '\u0e81'..'\u0e82'
    |   '\u0e84'
    |   '\u0e87'..'\u0e88'
    |   '\u0e8a'
    |   '\u0e8d'
    |   '\u0e94'..'\u0e97'
    |   '\u0e99'..'\u0e9f'
    |   '\u0ea1'..'\u0ea3'
    |   '\u0ea5'
    |   '\u0ea7'
    |   '\u0eaa'..'\u0eab'
    |   '\u0ead'..'\u0eb0'
    |   '\u0eb2'..'\u0eb3'
    |   '\u0ebd'
    |   '\u0ec0'..'\u0ec4'
    |   '\u0ec6'
    |   '\u0edc'..'\u0edd'
    |   '\u0f00'
    |   '\u0f40'..'\u0f47'
    |   '\u0f49'..'\u0f6a'
    |   '\u0f88'..'\u0f8b'
    |   '\u1000'..'\u1021'
    |   '\u1023'..'\u1027'
    |   '\u1029'..'\u102a'
    |   '\u1050'..'\u1055'
    |   '\u10a0'..'\u10c5'
    |   '\u10d0'..'\u10f8'
    |   '\u1100'..'\u1159'
    |   '\u115f'..'\u11a2'
    |   '\u11a8'..'\u11f9'
    |   '\u1200'..'\u1206'
    |   '\u1208'..'\u1246'
    |   '\u1248'
    |   '\u124a'..'\u124d'
    |   '\u1250'..'\u1256'
    |   '\u1258'
    |   '\u125a'..'\u125d'
    |   '\u1260'..'\u1286'
    |   '\u1288'
    |   '\u128a'..'\u128d'
    |   '\u1290'..'\u12ae'
    |   '\u12b0'
    |   '\u12b2'..'\u12b5'
    |   '\u12b8'..'\u12be'
    |   '\u12c0'
    |   '\u12c2'..'\u12c5'
    |   '\u12c8'..'\u12ce'
    |   '\u12d0'..'\u12d6'
    |   '\u12d8'..'\u12ee'
    |   '\u12f0'..'\u130e'
    |   '\u1310'
    |   '\u1312'..'\u1315'
    |   '\u1318'..'\u131e'
    |   '\u1320'..'\u1346'
    |   '\u1348'..'\u135a'
    |   '\u13a0'..'\u13f4'
    |   '\u1401'..'\u166c'
    |   '\u166f'..'\u1676'
    |   '\u1681'..'\u169a'
    |   '\u16a0'..'\u16ea'
    |   '\u16ee'..'\u16f0'
    |   '\u1700'..'\u170c'
    |   '\u170e'..'\u1711'
    |   '\u1720'..'\u1731'
    |   '\u1740'..'\u1751'
    |   '\u1760'..'\u176c'
    |   '\u176e'..'\u1770'
    |   '\u1780'..'\u17b3'
    |   '\u17d7' 
    |   '\u17db'..'\u17dc'
    |   '\u1820'..'\u1877'
    |   '\u1880'..'\u18a8'
    |   '\u1900'..'\u191c'
    |   '\u1950'..'\u196d'
    |   '\u1970'..'\u1974'
    |   '\u1d00'..'\u1d6b'
    |   '\u1e00'..'\u1e9b'
    |   '\u1ea0'..'\u1ef9'
    |   '\u1f00'..'\u1f15'
    |   '\u1f18'..'\u1f1d'
    |   '\u1f20'..'\u1f45'
    |   '\u1f48'..'\u1f4d'
    |   '\u1f50'..'\u1f57'
    |   '\u1f59'
    |   '\u1f5b'
    |   '\u1f5d'
    |   '\u1f5f'..'\u1f7d'
    |   '\u1f80'..'\u1fb4'
    |   '\u1fb6'..'\u1fbc'
    |   '\u1fbe'
    |   '\u1fc2'..'\u1fc4'
    |   '\u1fc6'..'\u1fcc'
    |   '\u1fd0'..'\u1fd3'
    |   '\u1fd6'..'\u1fdb'
    |   '\u1fe0'..'\u1fec'
    |   '\u1ff2'..'\u1ff4'
    |   '\u1ff6'..'\u1ffc'
    |   '\u203f'..'\u2040'
    |   '\u2054'
    |   '\u2071'
    |   '\u207f'
    |   '\u20a0'..'\u20b1'
    |   '\u2102'
    |   '\u2107'
    |   '\u210a'..'\u2113'
    |   '\u2115'
    |   '\u2119'..'\u211d'
    |   '\u2124'
    |   '\u2126'
    |   '\u2128'
    |   '\u212a'..'\u212d'
    |   '\u212f'..'\u2131'
    |   '\u2133'..'\u2139'
    |   '\u213d'..'\u213f'
    |   '\u2145'..'\u2149'
    |   '\u2160'..'\u2183'
    |   '\u3005'..'\u3007'
    |   '\u3021'..'\u3029'
    |   '\u3031'..'\u3035'
    |   '\u3038'..'\u303c'
    |   '\u3041'..'\u3096'
    |   '\u309d'..'\u309f'
    |   '\u30a1'..'\u30ff'
    |   '\u3105'..'\u312c'
    |   '\u3131'..'\u318e'
    |   '\u31a0'..'\u31b7'
    |   '\u31f0'..'\u31ff'
    |   '\u3400'..'\u4db5'
    |   '\u4e00'..'\u9fa5'
    |   '\ua000'..'\ua48c'
    |   '\uac00'..'\ud7a3'
    |   '\uf900'..'\ufa2d'
    |   '\ufa30'..'\ufa6a'
    |   '\ufb00'..'\ufb06'
    |   '\ufb13'..'\ufb17'
    |   '\ufb1d'
    |   '\ufb1f'..'\ufb28'
    |   '\ufb2a'..'\ufb36'
    |   '\ufb38'..'\ufb3c'
    |   '\ufb3e'
    |   '\ufb40'..'\ufb41'
    |   '\ufb43'..'\ufb44'
    |   '\ufb46'..'\ufbb1'
    |   '\ufbd3'..'\ufd3d'
    |   '\ufd50'..'\ufd8f'
    |   '\ufd92'..'\ufdc7'
    |   '\ufdf0'..'\ufdfc'
    |   '\ufe33'..'\ufe34'
    |   '\ufe4d'..'\ufe4f'
    |   '\ufe69'
    |   '\ufe70'..'\ufe74'
    |   '\ufe76'..'\ufefc'
    |   '\uff04'
    |   '\uff21'..'\uff3a'
    |   '\uff3f'
    |   '\uff41'..'\uff5a'
    |   '\uff65'..'\uffbe'
    |   '\uffc2'..'\uffc7'
    |   '\uffca'..'\uffcf'
    |   '\uffd2'..'\uffd7'
    |   '\uffda'..'\uffdc'
    |   '\uffe0'..'\uffe1'
    |   '\uffe5'..'\uffe6'
    |   ('\ud800'..'\udbff') ('\udc00'..'\udfff') 
    |   '\\' 'u'+  HexDigit HexDigit HexDigit HexDigit
    ;
                       
fragment 
IdentifierPart
    :   '\u0000'..'\u0008'
    |   '\u000e'..'\u001b'
    |   '\u0024'
    |   '\u0030'..'\u0039'
    |   '\u0041'..'\u005a'
    |   '\u005f'
    |   '\u0061'..'\u007a'
    |   '\u007f'..'\u009f'
    |   '\u00a2'..'\u00a5'
    |   '\u00aa'
    |   '\u00ad'
    |   '\u00b5'
    |   '\u00ba'
    |   '\u00c0'..'\u00d6'
    |   '\u00d8'..'\u00f6'
    |   '\u00f8'..'\u0236'
    |   '\u0250'..'\u02c1'
    |   '\u02c6'..'\u02d1'
    |   '\u02e0'..'\u02e4'
    |   '\u02ee'
    |   '\u0300'..'\u0357'
    |   '\u035d'..'\u036f'
    |   '\u037a'
    |   '\u0386'
    |   '\u0388'..'\u038a'
    |   '\u038c'
    |   '\u038e'..'\u03a1'
    |   '\u03a3'..'\u03ce'
    |   '\u03d0'..'\u03f5'
    |   '\u03f7'..'\u03fb'
    |   '\u0400'..'\u0481'
    |   '\u0483'..'\u0486'
    |   '\u048a'..'\u04ce'
    |   '\u04d0'..'\u04f5'
    |   '\u04f8'..'\u04f9'
    |   '\u0500'..'\u050f'
    |   '\u0531'..'\u0556'
    |   '\u0559'
    |   '\u0561'..'\u0587'
    |   '\u0591'..'\u05a1'
    |   '\u05a3'..'\u05b9'
    |   '\u05bb'..'\u05bd'
    |   '\u05bf'
    |   '\u05c1'..'\u05c2'
    |   '\u05c4'
    |   '\u05d0'..'\u05ea'
    |   '\u05f0'..'\u05f2'
    |   '\u0600'..'\u0603'
    |   '\u0610'..'\u0615'
    |   '\u0621'..'\u063a'
    |   '\u0640'..'\u0658'
    |   '\u0660'..'\u0669'
    |   '\u066e'..'\u06d3'
    |   '\u06d5'..'\u06dd'
    |   '\u06df'..'\u06e8'
    |   '\u06ea'..'\u06fc'
    |   '\u06ff'
    |   '\u070f'..'\u074a'
    |   '\u074d'..'\u074f'
    |   '\u0780'..'\u07b1'
    |   '\u0901'..'\u0939'
    |   '\u093c'..'\u094d'
    |   '\u0950'..'\u0954'
    |   '\u0958'..'\u0963'
    |   '\u0966'..'\u096f'
    |   '\u0981'..'\u0983'
    |   '\u0985'..'\u098c'
    |   '\u098f'..'\u0990'
    |   '\u0993'..'\u09a8'
    |   '\u09aa'..'\u09b0'
    |   '\u09b2'
    |   '\u09b6'..'\u09b9'
    |   '\u09bc'..'\u09c4'
    |   '\u09c7'..'\u09c8'
    |   '\u09cb'..'\u09cd'
    |   '\u09d7'
    |   '\u09dc'..'\u09dd'
    |   '\u09df'..'\u09e3'
    |   '\u09e6'..'\u09f3'
    |   '\u0a01'..'\u0a03'
    |   '\u0a05'..'\u0a0a'
    |   '\u0a0f'..'\u0a10'
    |   '\u0a13'..'\u0a28'
    |   '\u0a2a'..'\u0a30'
    |   '\u0a32'..'\u0a33'
    |   '\u0a35'..'\u0a36'
    |   '\u0a38'..'\u0a39'
    |   '\u0a3c'
    |   '\u0a3e'..'\u0a42'
    |   '\u0a47'..'\u0a48'
    |   '\u0a4b'..'\u0a4d'
    |   '\u0a59'..'\u0a5c'
    |   '\u0a5e'
    |   '\u0a66'..'\u0a74'
    |   '\u0a81'..'\u0a83'
    |   '\u0a85'..'\u0a8d'
    |   '\u0a8f'..'\u0a91'
    |   '\u0a93'..'\u0aa8'
    |   '\u0aaa'..'\u0ab0'
    |   '\u0ab2'..'\u0ab3'
    |   '\u0ab5'..'\u0ab9'
    |   '\u0abc'..'\u0ac5'
    |   '\u0ac7'..'\u0ac9'
    |   '\u0acb'..'\u0acd'
    |   '\u0ad0'
    |   '\u0ae0'..'\u0ae3'
    |   '\u0ae6'..'\u0aef'
    |   '\u0af1'
    |   '\u0b01'..'\u0b03'
    |   '\u0b05'..'\u0b0c'        
    |   '\u0b0f'..'\u0b10'
    |   '\u0b13'..'\u0b28'
    |   '\u0b2a'..'\u0b30'
    |   '\u0b32'..'\u0b33'
    |   '\u0b35'..'\u0b39'
    |   '\u0b3c'..'\u0b43'
    |   '\u0b47'..'\u0b48'
    |   '\u0b4b'..'\u0b4d'
    |   '\u0b56'..'\u0b57'
    |   '\u0b5c'..'\u0b5d'
    |   '\u0b5f'..'\u0b61'
    |   '\u0b66'..'\u0b6f'
    |   '\u0b71'
    |   '\u0b82'..'\u0b83'
    |   '\u0b85'..'\u0b8a'
    |   '\u0b8e'..'\u0b90'
    |   '\u0b92'..'\u0b95'
    |   '\u0b99'..'\u0b9a'
    |   '\u0b9c'
    |   '\u0b9e'..'\u0b9f'
    |   '\u0ba3'..'\u0ba4'
    |   '\u0ba8'..'\u0baa'
    |   '\u0bae'..'\u0bb5'
    |   '\u0bb7'..'\u0bb9'
    |   '\u0bbe'..'\u0bc2'
    |   '\u0bc6'..'\u0bc8'
    |   '\u0bca'..'\u0bcd'
    |   '\u0bd7'
    |   '\u0be7'..'\u0bef'
    |   '\u0bf9'
    |   '\u0c01'..'\u0c03'
    |   '\u0c05'..'\u0c0c'
    |   '\u0c0e'..'\u0c10'
    |   '\u0c12'..'\u0c28'
    |   '\u0c2a'..'\u0c33'
    |   '\u0c35'..'\u0c39'
    |   '\u0c3e'..'\u0c44'
    |   '\u0c46'..'\u0c48'
    |   '\u0c4a'..'\u0c4d'
    |   '\u0c55'..'\u0c56'
    |   '\u0c60'..'\u0c61'
    |   '\u0c66'..'\u0c6f'        
    |   '\u0c82'..'\u0c83'
    |   '\u0c85'..'\u0c8c'
    |   '\u0c8e'..'\u0c90'
    |   '\u0c92'..'\u0ca8'
    |   '\u0caa'..'\u0cb3'
    |   '\u0cb5'..'\u0cb9'
    |   '\u0cbc'..'\u0cc4'
    |   '\u0cc6'..'\u0cc8'
    |   '\u0cca'..'\u0ccd'
    |   '\u0cd5'..'\u0cd6'
    |   '\u0cde'
    |   '\u0ce0'..'\u0ce1'
    |   '\u0ce6'..'\u0cef'
    |   '\u0d02'..'\u0d03'
    |   '\u0d05'..'\u0d0c'
    |   '\u0d0e'..'\u0d10'
    |   '\u0d12'..'\u0d28'
    |   '\u0d2a'..'\u0d39'
    |   '\u0d3e'..'\u0d43'
    |   '\u0d46'..'\u0d48'
    |   '\u0d4a'..'\u0d4d'
    |   '\u0d57'
    |   '\u0d60'..'\u0d61'
    |   '\u0d66'..'\u0d6f'
    |   '\u0d82'..'\u0d83'
    |   '\u0d85'..'\u0d96'
    |   '\u0d9a'..'\u0db1'
    |   '\u0db3'..'\u0dbb'
    |   '\u0dbd'
    |   '\u0dc0'..'\u0dc6'
    |   '\u0dca'
    |   '\u0dcf'..'\u0dd4'
    |   '\u0dd6'
    |   '\u0dd8'..'\u0ddf'
    |   '\u0df2'..'\u0df3'
    |   '\u0e01'..'\u0e3a'
    |   '\u0e3f'..'\u0e4e'
    |   '\u0e50'..'\u0e59'
    |   '\u0e81'..'\u0e82'
    |   '\u0e84'
    |   '\u0e87'..'\u0e88'        
    |   '\u0e8a'
    |   '\u0e8d'
    |   '\u0e94'..'\u0e97'
    |   '\u0e99'..'\u0e9f'
    |   '\u0ea1'..'\u0ea3'
    |   '\u0ea5'
    |   '\u0ea7'
    |   '\u0eaa'..'\u0eab'
    |   '\u0ead'..'\u0eb9'
    |   '\u0ebb'..'\u0ebd'
    |   '\u0ec0'..'\u0ec4'
    |   '\u0ec6'
    |   '\u0ec8'..'\u0ecd'
    |   '\u0ed0'..'\u0ed9'
    |   '\u0edc'..'\u0edd'
    |   '\u0f00'
    |   '\u0f18'..'\u0f19'
    |   '\u0f20'..'\u0f29'
    |   '\u0f35'
    |   '\u0f37'
    |   '\u0f39'
    |   '\u0f3e'..'\u0f47'
    |   '\u0f49'..'\u0f6a'
    |   '\u0f71'..'\u0f84'
    |   '\u0f86'..'\u0f8b'
    |   '\u0f90'..'\u0f97'
    |   '\u0f99'..'\u0fbc'
    |   '\u0fc6'
    |   '\u1000'..'\u1021'
    |   '\u1023'..'\u1027'
    |   '\u1029'..'\u102a'
    |   '\u102c'..'\u1032'
    |   '\u1036'..'\u1039'
    |   '\u1040'..'\u1049'
    |   '\u1050'..'\u1059'
    |   '\u10a0'..'\u10c5'
    |   '\u10d0'..'\u10f8'
    |   '\u1100'..'\u1159'
    |   '\u115f'..'\u11a2'
    |   '\u11a8'..'\u11f9'
    |   '\u1200'..'\u1206'        
    |   '\u1208'..'\u1246'
    |   '\u1248'
    |   '\u124a'..'\u124d'
    |   '\u1250'..'\u1256'
    |   '\u1258'
    |   '\u125a'..'\u125d'
    |   '\u1260'..'\u1286'
    |   '\u1288'        
    |   '\u128a'..'\u128d'
    |   '\u1290'..'\u12ae'
    |   '\u12b0'
    |   '\u12b2'..'\u12b5'
    |   '\u12b8'..'\u12be'
    |   '\u12c0'
    |   '\u12c2'..'\u12c5'
    |   '\u12c8'..'\u12ce'
    |   '\u12d0'..'\u12d6'
    |   '\u12d8'..'\u12ee'
    |   '\u12f0'..'\u130e'
    |   '\u1310'
    |   '\u1312'..'\u1315'
    |   '\u1318'..'\u131e'
    |   '\u1320'..'\u1346'
    |   '\u1348'..'\u135a'
    |   '\u1369'..'\u1371'
    |   '\u13a0'..'\u13f4'
    |   '\u1401'..'\u166c'
    |   '\u166f'..'\u1676'
    |   '\u1681'..'\u169a'
    |   '\u16a0'..'\u16ea'
    |   '\u16ee'..'\u16f0'
    |   '\u1700'..'\u170c'
    |   '\u170e'..'\u1714'
    |   '\u1720'..'\u1734'
    |   '\u1740'..'\u1753'
    |   '\u1760'..'\u176c'
    |   '\u176e'..'\u1770'
    |   '\u1772'..'\u1773'
    |   '\u1780'..'\u17d3'
    |   '\u17d7'
    |   '\u17db'..'\u17dd'
    |   '\u17e0'..'\u17e9'
    |   '\u180b'..'\u180d'
    |   '\u1810'..'\u1819'
    |   '\u1820'..'\u1877'
    |   '\u1880'..'\u18a9'
    |   '\u1900'..'\u191c'
    |   '\u1920'..'\u192b'
    |   '\u1930'..'\u193b'
    |   '\u1946'..'\u196d'
    |   '\u1970'..'\u1974'
    |   '\u1d00'..'\u1d6b'
    |   '\u1e00'..'\u1e9b'
    |   '\u1ea0'..'\u1ef9'
    |   '\u1f00'..'\u1f15'
    |   '\u1f18'..'\u1f1d'
    |   '\u1f20'..'\u1f45'
    |   '\u1f48'..'\u1f4d'
    |   '\u1f50'..'\u1f57'
    |   '\u1f59'
    |   '\u1f5b'
    |   '\u1f5d'
    |   '\u1f5f'..'\u1f7d'
    |   '\u1f80'..'\u1fb4'
    |   '\u1fb6'..'\u1fbc'        
    |   '\u1fbe'
    |   '\u1fc2'..'\u1fc4'
    |   '\u1fc6'..'\u1fcc'
    |   '\u1fd0'..'\u1fd3'
    |   '\u1fd6'..'\u1fdb'
    |   '\u1fe0'..'\u1fec'
    |   '\u1ff2'..'\u1ff4'
    |   '\u1ff6'..'\u1ffc'
    |   '\u200c'..'\u200f'
    |   '\u202a'..'\u202e'
    |   '\u203f'..'\u2040'
    |   '\u2054'
    |   '\u2060'..'\u2063'
    |   '\u206a'..'\u206f'
    |   '\u2071'
    |   '\u207f'
    |   '\u20a0'..'\u20b1'
    |   '\u20d0'..'\u20dc'
    |   '\u20e1'
    |   '\u20e5'..'\u20ea'
    |   '\u2102'
    |   '\u2107'
    |   '\u210a'..'\u2113'
    |   '\u2115'
    |   '\u2119'..'\u211d'
    |   '\u2124'
    |   '\u2126'
    |   '\u2128'
    |   '\u212a'..'\u212d'
    |   '\u212f'..'\u2131'
    |   '\u2133'..'\u2139'
    |   '\u213d'..'\u213f'
    |   '\u2145'..'\u2149'
    |   '\u2160'..'\u2183'
    |   '\u3005'..'\u3007'
    |   '\u3021'..'\u302f'        
    |   '\u3031'..'\u3035'
    |   '\u3038'..'\u303c'
    |   '\u3041'..'\u3096'
    |   '\u3099'..'\u309a'
    |   '\u309d'..'\u309f'
    |   '\u30a1'..'\u30ff'
    |   '\u3105'..'\u312c'
    |   '\u3131'..'\u318e'
    |   '\u31a0'..'\u31b7'
    |   '\u31f0'..'\u31ff'
    |   '\u3400'..'\u4db5'
    |   '\u4e00'..'\u9fa5'
    |   '\ua000'..'\ua48c'
    |   '\uac00'..'\ud7a3'
    |   '\uf900'..'\ufa2d'
    |   '\ufa30'..'\ufa6a'
    |   '\ufb00'..'\ufb06'
    |   '\ufb13'..'\ufb17'
    |   '\ufb1d'..'\ufb28'
    |   '\ufb2a'..'\ufb36'
    |   '\ufb38'..'\ufb3c'
    |   '\ufb3e'
    |   '\ufb40'..'\ufb41'
    |   '\ufb43'..'\ufb44'
    |   '\ufb46'..'\ufbb1'
    |   '\ufbd3'..'\ufd3d'
    |   '\ufd50'..'\ufd8f'
    |   '\ufd92'..'\ufdc7'
    |   '\ufdf0'..'\ufdfc'
    |   '\ufe00'..'\ufe0f'
    |   '\ufe20'..'\ufe23'
    |   '\ufe33'..'\ufe34'
    |   '\ufe4d'..'\ufe4f'
    |   '\ufe69'
    |   '\ufe70'..'\ufe74'
    |   '\ufe76'..'\ufefc'
    |   '\ufeff'
    |   '\uff04'
    |   '\uff10'..'\uff19'
    |   '\uff21'..'\uff3a'
    |   '\uff3f'
    |   '\uff41'..'\uff5a'
    |   '\uff65'..'\uffbe'
    |   '\uffc2'..'\uffc7'
    |   '\uffca'..'\uffcf'
    |   '\uffd2'..'\uffd7'
    |   '\uffda'..'\uffdc'
    |   '\uffe0'..'\uffe1'
    |   '\uffe5'..'\uffe6'
    |   '\ufff9'..'\ufffb' 
    |   ('\ud800'..'\udbff') ('\udc00'..'\udfff')
    |   '\\' 'u'+  HexDigit HexDigit HexDigit HexDigit
    ;
