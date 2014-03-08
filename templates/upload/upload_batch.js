function s_truncate(str, len) {
    if(str.length > len) {
        newstr = str.substr(0, len - 3) + '...';
        return newstr;
    } else {
        return str;
    }
};

$(document).ready(function() {
    var g_FileCount = 0;
    var g_FileTotal = 0;
    var g_FileList  = null;
    var g_FileSizeTotal = 0;
    var g_FileSizeDone  = 0;

    $('#frm-upload-batch input[type="file"]').on('ajax', function() {
        var that = $(this);
        if (typeof this.files[g_FileCount] === 'undefined') {
            $('#uploadModal').modal('hide');
            $('#completeModal').modal('show');
            return false;
        }

        var pbar = $('#uploadModal #file-progress div.progress-bar');
        $(pbar).attr('aria-valuenow', 0).css({ 'width': '0%' }).empty();

        var fdata = new FormData();
        var file  = this.files[g_FileCount];

        fdata.append('replay', file);
        fdata.append('a', 'save');

        $('#uploadModal #file-progress h5').text(s_truncate(file.name, 50));

        $.ajax({
            'type': 'POST',
            'url': '/upload/process',
            'data': fdata,
            'contentType': false,
            'processData': false,
            'cache': false,
            'xhr': function() {  
                var xhr = $.ajaxSettings.xhr();
                if(xhr.upload){ 
                    xhr.upload.addEventListener('progress', function(evt) {
                        if(evt.lengthComputable) {
                            perc = Math.round(evt.loaded / evt.total * 100);
                            g_FileSizeDone += evt.loaded;
                            $(pbar).attr('aria-valuenow', perc).css({ 'width': perc + '%' });
                            if(perc > 10) $(pbar).text(perc + '%');
                        }
                        if(g_FileSizeTotal > 0 && g_FileSizeDone > 0) {
                            var tperc = Math.round(g_FileSizeDone / g_FileSizeTotal * 100);
                            $('#uploadModal #total-progress div.progress-bar').css({ 'width': tperc + '%' }).attr('aria-valuenow', tperc);
                            if(tperc > 10) $('#uploadModal #total-progress div.progress-bar').text(tperc + '%');
                        }
                    }, false);
                }
                return xhr;
            },
            'error': function() {
                g_FileCount++;
                that.trigger('ajax');
            },
            'success': function(d, t, x) {
                g_FileCount++;
                that.trigger('ajax');
            },
        });
    });

    //.trigger('ajax'); // Execute only the first input[multiple] AJAX, we aren't using $
    $('#frm-upload-batch button.btn-primary').click(function() {
        if($(this).hasClass('disabled')) return false;
        $('#frm-upload-batch input[type="file"]').prop('disabled', true);
        $(this).addClass('disabled');

        g_FileList = $('#frm-upload-batch input[type="file"]')[0].files;

        if(g_FileList.length > 0) {
            g_FileTotal = g_FileList.length;
            $('#uploadModal').modal('show');
            $('#frm-upload-batch input[type="file"]').trigger('ajax');
            _(g_FileList).each(function(file) {
                g_FileSizeTotal += file.size;
            });
            $('#uploadModal #total-progress div.progress-bar').css({ 'width': '0%' }).attr('aria-valuenow', 0).attr('aria-valuemax', g_FileSizeTotal).attr('aria-valuemin', 0);
        } else {
            $('#frm-upload-batch input[type="file"]').prop('disabled', false);
            $(this).removeClass('disabled');
            alert('You should select some files, it helps...');
        }
    });
    $('button#close-complete').click(function() {
        $('#completeModal').modal('hide');
        $('div#pleaseWaitModal').modal('show');
        $('body').oneTime(2000, function() {
            document.location.reload();
        });
    });
    $('#completeModal').modal({
        backdrop: true,
        keyboard: true,
        show: false,
    });
    $('#uploadModal').modal({
        backdrop: true,
        keyboard: false,
        show: false,
    });
});
