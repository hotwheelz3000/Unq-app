/// JavaScript injected into unqx.site. Defines `window.__unqPaste(text)`, which
/// replaces everything in the code editor with `text` and returns which kind of
/// editor it found ("cm6", "cm5", "monaco", "ace", "textarea", "editable" or "none").
enum PasteScript {
    static let source = #"""
    (function () {
      if (window.__unqPaste) { return; }

      function setTextarea(ta, text) {
        var setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set;
        setter.call(ta, text);
        ta.dispatchEvent(new Event('input', { bubbles: true }));
        ta.dispatchEvent(new Event('change', { bubbles: true }));
      }

      function visible(el) {
        if (!el) { return false; }
        var r = el.getBoundingClientRect();
        return r.width > 20 && r.height > 20;
      }

      window.__unqPaste = function (text) {
        // CodeMirror 6: the content element keeps a pointer to its view
        // (cmTile in newer versions, cmView in older ones).
        var cm6 = document.querySelector('.cm-content');
        var cmRef = cm6 && (cm6.cmTile || cm6.cmView);
        if (cmRef && cmRef.view && cmRef.view.dispatch) {
          var view = cmRef.view;
          view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: text } });
          view.focus();
          return 'cm6';
        }

        // CodeMirror 5.
        var cm5 = document.querySelector('.CodeMirror');
        if (cm5 && cm5.CodeMirror) {
          cm5.CodeMirror.setValue(text);
          return 'cm5';
        }

        // Monaco.
        if (window.monaco && window.monaco.editor) {
          var models = window.monaco.editor.getModels();
          if (models.length) {
            models[0].setValue(text);
            return 'monaco';
          }
        }

        // Ace.
        var aceEl = document.querySelector('.ace_editor');
        if (aceEl && window.ace) {
          window.ace.edit(aceEl).setValue(text, -1);
          return 'ace';
        }

        // A plain, visible textarea.
        var areas = Array.prototype.slice.call(document.querySelectorAll('textarea'));
        var ta = areas.filter(visible)[0];
        if (ta) {
          setTextarea(ta, text);
          return 'textarea';
        }

        // Any other editable area (including CodeMirror 6 without its view pointer).
        var editable = document.querySelector('.cm-content, [contenteditable="true"], [contenteditable=""]');
        if (editable) {
          editable.focus();
          document.execCommand('selectAll', false, null);
          document.execCommand('insertText', false, text);
          return 'editable';
        }

        return 'none';
      };
    })();
    """#
}
