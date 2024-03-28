// for click-to-copy
$(function() {
    function styleCodeBlock() {
        $('.highlight>pre').hover(function() {
            if ($(this).parent().hasClass("linenodiv")) return;
            $(this).attr('click-to-copy', 'click to copy...');
        });
        $('.highlight>pre').mouseup(function(){
            if ($(this).parent().hasClass("linenodiv")) return;
            $(this).attr('click-to-copy', 'click to copy...');
            var selectionText = getSelectionText();
            if (selectionText.trim().length > 0) return;
            var result = copyClipboard(this);
            if (result) {
                $(this).attr('click-to-copy', 'copied!');
            }
        });
    }

    function getSelectionText() {
        var text = "";
        if (window.getSelection) {
            text = window.getSelection().toString();
        } else if (document.selection && document.selection.type != "Control") {
            text = document.selection.createRange().text;
        }
        return text;
    }

    function copyClipboard(selector) {
        var body = document.body;
        if(!body) return false;

        var $target = $(selector);
        if ($target.length === 0) { return false; }

        var text = $target.text();
        var textarea = document.createElement('textarea');
        textarea.value = text;
        document.body.appendChild(textarea);
        textarea.select();
        var result = document.execCommand('copy');
        document.body.removeChild(textarea);
        return result;
    }

    styleCodeBlock();
});