# Camera frame and patient names: 1.5.2+18

The camera border was painted as a background decoration, allowing the camera/photo child to cover the middle of its top and bottom edges. The same rounded blue border now paints in the foreground. Preview aspect ratio, focus coordinates and image analysis are unchanged.

Saved records now have an optional patient name. Unlock history and tap the pencil beside a record to add or edit it. The name is also visible on the protected result page, with an edit action. A blank name removes the current label. Existing unnamed records still load, and names are not mandatory to scan or use safety guidance.

Names are trimmed, support Unicode, and are limited to a single line of 100 characters. Edits preserve record ID, saved timestamp, scan, symptoms and recorded interpretation. They use the authenticated, serialized, encrypted index and the existing atomic/recovery write path. No plaintext name file, network service or new encryption key is introduced. Screenshot protection and session-expiry/background locking apply to the editor. Unsaved input is cleared on background/expiry; keyboard suggestions, autocorrect and personalized learning are disabled for this field.

Tests cover encrypted name persistence and removal, unchanged record contents, missing/invalid edits preserving history, backwards-compatible unnamed records, and protected name editing at 360-pixel phone width. The image classifier, model assets and Bayesian values are unchanged. Prior classifier regression evidence is retained with explicit provenance rather than reported as a new evaluation.

The user confirmed that history unlock works after the 1.5.1+17 update. This is a user-reported unlock result, not completion of the full two-device security/migration acceptance matrix.

Release evidence and the signed APK: `output/device_pilot/2026-10-10/1.5.2+18/`. After installation, verify the continuous border for both live camera and selected photo, then add, change and clear a test record name. Backgrounding should hide protected names until history is unlocked again.
