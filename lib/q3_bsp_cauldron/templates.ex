defmodule Q3BspCauldron.Templates do
  require EEx

  # This compiles the template into the beam file at compile time
  def file_listing(assigns) do
    template_path =
      Path.join(
        :code.priv_dir(:q3_bsp_cauldron),
        "templates/file_listing.html.eex"
      )

    EEx.eval_file(template_path, assigns: assigns)
  end
end
