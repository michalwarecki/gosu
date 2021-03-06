/*
 * Copyright 2012. Guidewire Software, Inc.
 */

package gw.lang.parser.statements;

import gw.lang.parser.IParsedElement;

import java.util.List;

public interface IUsesStatementList extends IParsedElement {
  List<IUsesStatement> getUsesStatements();
}
