var handleProcess = null;
var timerID = null;
var jobIDstatus = {};
var g_batchSequence = 1;

function processBackground() {
    clearTimer(timerID); // and really that's all there's to it 
}

handleProcess = function(jobid) {
    var nonce = new Date().getTime();
    var processURL = 'http://api.wotreplays.org/v1/process/status/' + jobid;
    $('.process-log').addClass('job-' + jobid);

    var processLog = $('#processModal .process-log.job-' + jobid);

    $.getJSON(processURL, { 'seq': nonce, 't': '[% config.secrets.apitoken %]' }, function(d) {
        if(d.complete) {
            $('#processModal').modal('hide');
            if(d.status == 1) {
                $('#replay-file-link').html(
                    $('<a>').attr('href', '[% config.urls.replays %]/' + d.file).html('[% config.urls.replays %]/' + d.file)
                );
                $('#replay-page-link').html(
                    $('<a>').attr('href', '[% config.urls.app %]/replay/' + d.replayid + '.html').html('[% config.urls.app %]/replay/' + d.replayid + '.html')
                );

                if(d.banner.available) {
                    $('#banner-available').show();
                    $('#banner-unavailable').hide();

                    $('#banner-image').attr('src', '[% config.urls.banners %]/' + d.banner.url_path);
                    $('#banner-bbcode').text(
                        '[url=[% config.urls.app %]/replay/' + d.replayid + '.html]' + "\n" +
                        '[img][% config.urls.banners %]/' + d.banner.url_path + '[/img]' + "\n" +
                        '[/url]'
                    );
                } else {
                    $('#banner-available').hide();
                    $('#banner-unavailable').show();
                }
                $('button#close-and-view').attr('href', '[% config.urls.app %]/replay/' + d.replayid + '.html');
                $('#completeModal').modal('show');
            } else if(d.status == -1) {
                if(!d.error) d.error = 'Unknown error occurred during processing';
                $.bootstrapGrowl(d.error, {
                    type: 'danger',
                    allow_dismiss: true,
                    delay: 20000,
                    offset: { from: 'top', amount: 40 },
                });
            }
        } else {
            if(d.status == 0) {
                processLog.empty();

                var pt = $('<table>');
                pt.addClass('table');
                var tb = $('<tbody/>');

                if(d.status_text.length > 0) {
                    d.status_text.forEach(function(element) {
                        var row = $('<tr/>');
                        row.append($('<td/>').text(element.text).addClass('text'));

                        if(element.done) {
                            row.append($('<td/>').append($('<span/>').addClass('green').text('DONE')).addClass('spinner'));
                        } else {
                            if(element.type == 'spinner') {
                                row.append($('<td/>').append($('<span/>').addClass('spinner')).addClass('spinner'));
                            } else if(element.type == 'progress') {
                                var p = $('<div/>').addClass('progress')
                                    .append(
                                        $('<div/>').addClass('progress-bar progress-bar-success').css({ 'width': element.perc + '%' })
                                    );
                                row.append($('<td/>').append(p).addClass('spinner'));
                            }
                        }
                        tb.append(row);
                    });
                    pt.append(tb);
                    processLog.html(pt);
                } else {
                    var pt = $('<table>').addClass('table');
                    var tb = $('<tbody/>');
                    var row = $('<tr/>');

                    row.append($('<td/>').text('Waiting for free processing slot: [' + d.position + '/' + d.pending + ']').addClass('text'));
                    row.append($('<td/>').append($('<span/>').addClass('spinner')).addClass('spinner'));

                    tb.append(row);
                    pt.append(tb);

                    processLog.html(pt);
                }

                timerID = setTimeout(function() {
                    handleProcess(jobid);
                }, 2500);
            } else if(d.status == -1) {
                $('#processModal').modal('hide');
                if(!d.error) d.error = 'Unknown error occurred during processing';
                $.bootstrapGrowl(d.error, {
                    type: 'danger',
                    offset: { from: 'top', amount: 40 },
                    allow_dismiss: true,
                    delay: 20000,
                });
            }
        }
    });
}

function processBatch(jid, batchseq) {
    return function() {
        var jobid = jid;
        var bs = batchseq;
        var nonce = new Date().getTime();
        var processURL = 'http://api.wotreplays.org/v1/process/status/' + jobid;
        $.getJSON(processURL, { 'seq': nonce, 't': '[% config.secrets.apitoken %]' }, function(d) {
            if(d.complete) {
                if(d.status == 1) {
                    $('#batch-tracker #batch-' + bs + ' td.status').empty().html(
                        $('<div>').addClass('alert alert-success').text('DONE')
                    );
                    $('#frm-upload-batch-' + bs).stopTime();
                } else if(d.status == -1) {
                    $('#batch-tracker #batch-' + bs + ' td.status').empty().html(
                        $('<div>').addClass('alert alert-danger').text(d.error || 'Unknown error')
                    );
                    $('#frm-upload-batch-' + bs).stopTime();
                }
            } else {
                if(d.status == -1) {
                    $('#batch-tracker #batch-' + bs + ' td.status').empty().html(
                        $('<div>').addClass('alert alert-danger').text(d.error || 'Unknown error')
                    );
                    $('#frm-upload-batch-' + bs).stopTime();
                }
            }
        });
    }
}

function newBatchForm(blseq) {
    var f= function() {
        var batchSequence = blseq;
        var tmpl = $('script#batch-form-template').html();
        // if we have a current one, hide it 
        $('#container-frm-upload-batch .uploadform').addClass('hide');
        var cont = $('<div>').attr('id', 'frm-upload-batch-' + batchSequence).addClass('uploadform').html(tmpl);

        $(cont).find('.i18n').i18n();

        $(cont).find('input[type="file"]').attr('id', 'replayFileBatch-' + batchSequence);
        $('#container-frm-upload-batch').prepend($(cont));

        $('#container-frm-upload-batch #frm-upload-batch-' + batchSequence + ' form button').on('click', function() {
            if($(this).hasClass('disabled')) return false;
            $(this).addClass('disabled');
            var file = $(this).parent().parent().find('input[type="file"]').val();
            $('#batch-tracker').removeClass('hide');
            $('#batch-tracker table tbody').prepend( $('<tr>').attr('id', 'batch-' + batchSequence).append($('<td>').addClass('file').text(file.replace(/.*\\/g, '')), $('<td>').addClass('status').text('') ) );
            $('#batch-tracker #batch-' + batchSequence + ' td.status').html('<div class="progress"><div class="progress-bar" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100" style="width: 0%"></div></div>');
            $('#frm-upload-batch-' + batchSequence + ' form').ajaxSubmit({
                uploadProgress: function(event, position, total, percentComplete) {
                    var percentVal = percentComplete + '%';
                    $('#batch-tracker #batch-' + batchSequence + ' td.status div.progress-bar').attr('aria-valuenow', percentVal).css({ width: percentVal + '%' });
                },
                error: function(x, t, e) {
                    $('#batch-tracker #batch-' + batchSequence + ' td.status').empty().html(
                        $('<div>').addClass('alert alert-danger').text(e)
                    );
                },
                success: function(d, t, x) {
                    if(d.ok && d.ok == 1) {
                        $('#batch-tracker #batch-' + batchSequence + ' td.status').empty().html(
                            $('<span>').addClass('spinner')
                        );
                        $('#frm-upload-batch-' + batchSequence).everyTime(5000, processBatch(d.jid, batchSequence));
                    } else {
                        if(d.error) {
                            $('#batch-tracker #batch-' + batchSequence + ' td.status').empty().html(
                                $('<div>').addClass('alert alert-danger').text(d.error)
                            );
                        } else {
                            $('#batch-tracker #batch-' + batchSequence + ' td.status').empty().html(
                                $('<div>').addClass('alert alert-danger').text('Store fail')
                            );
                        }
                    }
                },
            });
            newBatchForm(g_batchSequence)();
        });
    };
    g_batchSequence = g_batchSequence + 1;
    return f;
}

$(document).ready(function() {
    newBatchForm(g_batchSequence)();

    $('button#process-background').click(function() {
        $('#processModal').modal('hide');
        processBackground();
    });
    $('button#close-and-view').click(function() {
        var href = $(this).attr('href');
        $('#completeModal').modal('hide');
        document.location.href = href;
    });

    $('#frm-upload').ajaxForm({
        clearForm: true,
        resetForm: true,
        beforeSend: function() {
            $('#uploadModal .progress-bar').attr('aria-valuenow', 0).css({ 'width': '0%' });
            $('#uploadModal').modal({
                backdrop: 'static',
                keyboard: false,
                show: true,
            });
            $('#processModal').modal({
                backdrop: 'static',
                keyboard: false,
                show: false,
            });
            $('#completeModal').modal({
                backdrop: true,
                keyboard: true,
                show: false,
            });
        },
        uploadProgress: function(event, position, total, percentComplete) {
            var percentVal = percentComplete + '%';
            $('#uploadModal .progress-bar span').html(percentVal);
            $('#uploadModal .progress-bar').css({ width: percentVal });
        },
        error: function(x, t, e) {
            $('#uploadModal').modal('hide');
            console.log('Error occurred during upload, try again: ' + e);
            $.bootstrapGrowl('Error occurred during upload, try again: ' + e, {
                offset: { from: 'top', amount: 40 },
                allow_dismiss: true,
                delay: 20000,
                type: 'danger',
            });
        },
        success: function(d, t, x) {
            $('#uploadModal').modal('hide');
            if(d.ok && d.ok == 1) {
                $('#processModal').modal('show');
                handleProcess(d.jid);
            } else {
                if(d.error) {
                    $.bootstrapGrowl(d.error, {
                        offset: { from: 'top', amount: 40 },
                        allow_dismiss: true,
                        delay: 20000,
                        type: 'danger',
                    });
                } else {
                    $.bootstrapGrowl('Error occurred while storing replay, try again...', {
                        offset: { from: 'top', amount: 40 },
                        allow_dismiss: true,
                        delay: 20000,
                        type: 'danger',
                    });
                }
            }
        },
    });

});    
