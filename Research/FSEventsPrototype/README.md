# FSEvents and Bookmark Prototype

Purpose: observe recursive file monitoring, stream recovery signals, and selected-folder bookmark lifecycle on current macOS.

This research harness must immediately copy callback data into typed Sendable values. It is not a production module.

`repair-bookmark PROJECT-ID FOLDER FILE` replaces the bookmark data while carrying the caller-provided project identity through the repair result. It is a command-line evidence harness, not project persistence code.
