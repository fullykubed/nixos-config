
return {
  -- Note 1: Neotree doesn't seem to restore properly so we have to close
  -- it before save and then open it again
  {
    'rmagatti/auto-session',
    config = true,
    opts = {
      auto_save_enabled = true,
      auto_restore_enabled = true,
      pre_save_cmds = {"Neotree action=close"},
      post_restore_cmds = {"Neotree action=show"}
    }
  }
}
