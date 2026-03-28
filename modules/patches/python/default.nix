# Python package patches — test fixes and CA workarounds
_:
let
  overlay = _final: prev: {
    # bootstrap-packaging: disable CA derivations
    # CA output ingestion fails because the Nix daemon doesn't recreate the
    # __pycache__ directory tree at the content-addressed store path, causing:
    #   "creating file .../__pycache__/metadata.cpython-312.pyc: No such file or directory"
    # followed by a NOT NULL constraint failure in the Realisations table.
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (_pyfinal: pyprev: {
        bootstrap = pyprev.bootstrap // {
          packaging = pyprev.bootstrap.packaging.overrideAttrs { __contentAddressed = false; };
        };
      })
    ];

    python312 = prev.python312.override {
      packageOverrides = _pyfinal: pyprev: {
        # websockets: Skip flaky test with race condition in sync connection handling
        # Test fails intermittently depending on builder load due to timing-sensitive connection state
        # See: https://github.com/NixOS/nixpkgs/issues/366256
        websockets = pyprev.websockets.overrideAttrs (old: {
          disabledTests = (old.disabledTests or [ ]) ++ [
            "test_writing_in_recv_events_fails"
          ];
        });

        # anyio: Skip flaky tests — race conditions in test teardown and log capture
        # test_single_thread: threading.active_count() non-deterministic with pytest-xdist
        # test_thread_cancelled_and_abandoned: uvloop event loop closes before worker thread
        #   calls call_soon_threadsafe, causing RuntimeError in teardown
        # test_handshake_fail: asyncio emits a spurious slow-task WARNING that adds an
        #   extra LogRecord, making `assert len(caplog.records) == 1` fail with 2
        # See: https://github.com/NixOS/nixpkgs/issues/448125
        anyio = pyprev.anyio.overrideAttrs (old: {
          disabledTests = (old.disabledTests or [ ]) ++ [
            "test_single_thread"
            "test_thread_cancelled_and_abandoned"
            "test_handshake_fail"
          ];
        });

        # rich: Skip test_brokenpipeerror — sandbox timing issue
        # BrokenPipeError timing is non-deterministic in sandbox; process exits
        # before SIGPIPE arrives, so returncode is 0 instead of expected 1
        rich = pyprev.rich.overrideAttrs (old: {
          disabledTests = (old.disabledTests or [ ]) ++ [
            "test_brokenpipeerror"
          ];
        });
      };
    };

    python313 = prev.python313.override {
      packageOverrides = _pyfinal: pyprev: {
        # distutils: test_build_clib.test_run calls self.skipTest (unittest API)
        # but the test class isn't a unittest.TestCase — AttributeError
        distutils = pyprev.distutils.overrideAttrs {
          doInstallCheck = false;
        };

        # mss: Disable install checks — tests require X11 display unavailable in sandbox
        mss = pyprev.mss.overrideAttrs {
          doInstallCheck = false;
        };

        # pytest-xdist: test_workqueue_ordered_by_input asserts worker gw0 gets
        # work first, but scheduling is non-deterministic in sandbox
        pytest-xdist = pyprev.pytest-xdist.overrideAttrs (old: {
          disabledTests = (old.disabledTests or [ ]) ++ [
            "test_workqueue_ordered_by_input"
          ];
        });

        # rich: Skip test_brokenpipeerror — sandbox timing issue
        # BrokenPipeError timing is non-deterministic in sandbox; process exits
        # before SIGPIPE arrives, so returncode is 0 instead of expected 1
        rich = pyprev.rich.overrideAttrs (old: {
          disabledTests = (old.disabledTests or [ ]) ++ [
            "test_brokenpipeerror"
          ];
        });

        # numpy: Skip test_cli_obj — meson subprocess can't find mold linker
        numpy = pyprev.numpy.overrideAttrs (old: {
          disabledTests = (old.disabledTests or [ ]) ++ [
            "test_cli_obj"
          ];
        });
      };
    };
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
