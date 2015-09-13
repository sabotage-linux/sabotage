/* Pango
 * querymodules.c:
 *
 * Copyright (C) 1999 Red Hat Software
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include <stdlib.h>
#include "config.h"

#include <glib.h>
#include <gmodule.h>
#include "pango-break.h"
#include "pango-context.h"
#include "pango-impl-utils.h"
#include "pango-engine.h"
#include "pango-enum-types.h"

#include <errno.h>
#include <string.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <glib/gprintf.h>

#ifdef USE_LA_MODULES
#define SOEXT ".la"
#else
#define SOEXT ("." G_MODULE_SUFFIX)
#endif
#define SOEXT_LEN ((int) strlen (SOEXT))

static gboolean
string_needs_escape (const char *str)
{
  while (TRUE)
    {
      char c = *str++;

      if (!c)
	return FALSE;
      else if (c == '\"' || c == '\\' || g_ascii_isspace (c))
	return TRUE;
    }
}

static char *
escape_string (const char *str)
{
  GString *result = g_string_new (NULL);

  while (TRUE)
    {
      char c = *str++;

      switch (c)
	{
	case '\0':
	  goto done;
	case '\n':
	  g_string_append (result, "\\n");
	  break;
	case '\"':
	  g_string_append (result, "\\\"");
	  break;
	case '\\':
	  g_string_append (result, "\\\\");
	  break;
	default:
	  g_string_append_c (result, c);
	}
    }

 done:
  return g_string_free (result, FALSE);
}

#define GET_SYMBOL(module,name,location)                 \
  g_module_symbol (module, name, (gpointer *)(void *)&location)

static const char *
string_from_script (PangoScript script)
{
  static GEnumClass *class = NULL;
  GEnumValue *value;
  if (!class)
    class = g_type_class_ref (PANGO_TYPE_SCRIPT);

  value = g_enum_get_value (class, script);
  if (!value)
    {
      g_warning ("Engine reported invalid script value %d\n", script);
      return string_from_script (PANGO_SCRIPT_INVALID_CODE);
    }

  return value->value_nick;
}


static char* prefix = "";

static void
query_module (const char *dir, const char *name)
{
  void (*list) (PangoEngineInfo **engines, gint *n_engines);
  void (*init) (GTypeModule *module);
  void (*exit) (void);
  PangoEngine *(*create) (const gchar *id);

  GModule *module;
  gchar *path;

  if (g_path_is_absolute (name))
    path = g_strdup (name);
  else
    path = g_build_filename (dir, name, NULL);

  module = g_module_open (path, G_MODULE_BIND_LAZY | G_MODULE_BIND_LOCAL);

  if (!module)
    g_printerr ("Cannot load module %s: %s\n", path, g_module_error ());

  if (module &&
      GET_SYMBOL (module, "script_engine_list", list) &&
      GET_SYMBOL (module, "script_engine_init", init) &&
      GET_SYMBOL (module, "script_engine_exit", exit) &&
      GET_SYMBOL (module, "script_engine_create", create))
    {
      gint i,j;
      PangoEngineInfo *engines;
      gint n_engines;

      (*list) (&engines, &n_engines);

      for (i=0; i<n_engines; i++)
	{
	  const gchar *quote;
	  gchar *quoted_path;
	size_t l = strlen(prefix);

	  if (string_needs_escape (path + l))
	    {
	      quote = "\"";
	      quoted_path = escape_string (path + l);
	    }
	  else
	    {
	      quote = "";
	      quoted_path = g_strdup (path + l);
	    }

	  g_printf ("%s%s%s %s %s %s", quote, quoted_path, quote,
		    engines[i].id, engines[i].engine_type, engines[i].render_type);
	  g_free (quoted_path);

	  for (j=0; j < engines[i].n_scripts; j++)
	    {
	      g_printf (" %s:%s",
			string_from_script (engines[i].scripts[j].script),
			engines[i].scripts[j].langs);
	    }
	  g_printf ("\n");
	}
    }
  else
    {
      g_printerr ("%s does not export Pango module API\n", path);
    }

  g_free (path);
  if (module)
    g_module_close (module);
}

static G_GNUC_NORETURN gboolean
show_version(const char *name G_GNUC_UNUSED,
	     const char *arg G_GNUC_UNUSED,
	     gpointer    data G_GNUC_UNUSED,
	     GError    **error G_GNUC_UNUSED)
{
  g_printf("pango-querymodules (%s) %s\n", PACKAGE_NAME, PACKAGE_VERSION);
  g_printf("module interface version: %s\n", MODULE_VERSION);
  exit(0);
}

int
main (int argc, char **argv)
{
  char *cwd;
  int i;
  char *path;
	char buf[4096];

  g_type_init ();

  g_printf ("# Pango Modules file\n"
	    "# Automatically generated file, do not edit\n"
	    "#\n");

  if (argc == 1 || (argc == 2 && !memcmp(argv[1], "prefix=", 7)))		/* No arguments given */
    {
      char **dirs;
      int i;

      path = pango_config_key_get ("Pango/ModulesPath");
      if (!path)
	path = g_build_filename (pango_get_lib_subdirectory (),
				 MODULE_VERSION,
				 "modules",
				 NULL);

	if(argc == 2) prefix=argv[1]+7;
	snprintf(buf, sizeof(buf), "%s%s", prefix, path);

      g_free (path);

	path=buf;


      g_printf ("# ModulesPath = %s\n#\n", path);

      dirs = pango_split_file_list (path);


      for (i=0; dirs[i]; i++)
	{
	  GDir *dir = g_dir_open (dirs[i], 0, NULL);
	  if (dir)
	    {
	      const char *dent;

	      while ((dent = g_dir_read_name (dir)))
		{
		  int len = strlen (dent);
		  if (len > SOEXT_LEN && strcmp (dent + len - SOEXT_LEN, SOEXT) == 0)
		    query_module (dirs[i], dent);
		}

	      g_dir_close (dir);
	    }
	}

      g_strfreev (dirs);
    }
  else
    {
      cwd = g_get_current_dir ();

      for (i=1; i<argc; i++)
	query_module (cwd, argv[i]);

      g_free (cwd);
    }

  return 0;
}
