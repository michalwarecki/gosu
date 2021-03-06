/*
 * Copyright 2012. Guidewire Software, Inc.
 */

package gw.lang.cli;

import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Inherited;


@Retention(RetentionPolicy.RUNTIME)
@Inherited
public @interface ArgNames
{
  public abstract String[] names();
}