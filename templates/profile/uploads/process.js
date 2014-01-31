var handleProcess = null;
var timerID = null;
var jobIDstatus = {};

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
            document.location.reload();
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
                document.location.reload();
            }
        }
    });
}

$(document).ready(function() {
    $('button#process-close').click(function() {
        $('#processModal').modal('hide');
        processBackground();
        return false;
    });
    $('a.status-view').click(function() {
        var jobid = $(this).attr('href');
        $('#processModal').modal('show');
        handleProcess(jobid);
        return false;
    });
});    
