$(document).ready(function() {
// Main javascript functions used by place pages
// validate contact forms
$.validator.setDefaults({
	submitHandler: function() { 
	//Ajax submit for contact form
    $.ajax({
            type:'POST', 
            url: $('#email').attr('action'), 
            data: $('#email').serializeArray(),
            dataType: "html", 
            success: function(response) {
                var temp = response;
                if(temp == 'Recaptcha fail') {
                    alert('please try again');
                    Recaptcha.reload();
                }else {
                    $('div#modal-body').html(temp);
                    $('#email-submit').hide();
                    $('#email')[0].reset();
                }
               // $('div#modal-body').html(temp);
        }});
	}
});


$("#email").validate({
		rules: {
			recaptcha_challenge_field: "required",
			name: "required",
			email: {
				required: true,
				email: true
			},
			subject: {
				required: true,
				minlength: 2
			},
			comments: {
				required: true,
				minlength: 2
			}
		},
		messages: {
			name: "Please enter your name",
            subject: "Please enter a subject",
			comments: "Please enter a comment",
			email: "Please enter a valid email address",
			recaptcha_challenge_field: "Captcha helps prevent spamming. This field cannot be empty"
		}
});

//Expand works authored-by in persons page
$('a.getData').click(function(event) {
    event.preventDefault();
    var title = $(this).data('label');
    var URL = $(this).data('ref');
    $("#moreInfoLabel").text(title);
    $('#moreInfo-box').load(URL + " #search-results");
});
    
$('#showSection').click(function(event) {
    event.preventDefault();
    $('#recComplete').load('/exist/apps/srophe/documentation/faq.html #selection');
});

//Changes text on toggle buttons, toggle funtion handled by Bootstrap
$('.togglelink').click(function(e){
    e.preventDefault();
    var el = $(this);
    if (el.text() == el.data("text-swap")) {
          el.text(el.data("text-original"));
        } else {
          el.data("text-original", el.text());
          el.text(el.data("text-swap"));
        }
});           



if (navigator.appVersion.indexOf("Mac") > -1 || navigator.appVersion.indexOf("Linux") > -1) {
    $('.get-syriac').show();
}

$(function () {
  $('[data-toggle="tooltip"]').tooltip()
})

$('html').click(function() {
                    $('#footnoteDisplay').hide();
                    $('#footnoteDisplay div.content').empty();
                })
                
                $('.footnote-ref a').click(function(e) {
                    e.stopPropagation();
                    e.preventDefault();
                    var link = $(this);
                    var href = $(this).attr('href');
                    var content = $(href).html()
                    $('#footnoteDisplay').css('display','block');
                    $('#footnoteDisplay').css({'top':e.pageY-50,'left':e.pageX+25, 'position':'absolute'});
                    $('#footnoteDisplay div.content').html( content );    
                });

//Get RDF
            $('#relatedResources').children('form').each(function () {
                var url = $(this).attr('action');
                $.get(url, $(this).serialize(), function (data) {
                    var showOtherResources = $("#listRelatedResources");
                    var dataArray = data.results.bindings;
                    if (! jQuery.isArray(dataArray)) dataArray =[dataArray];
                    $.each(dataArray, function (currentIndex, currentElem) {
                        var relatedResources = 'Resources related to <a href="' + currentElem.uri.value + '">' + currentElem.label.value + '</a> '
                        var relatedSubjects = (currentElem.subjects) ? '<div class="indent">' + currentElem.subjects.value + ' related subjects</div>': ''
                        var relatedCitations = (currentElem.citations) ? '<div class="indent">' + currentElem.citations.value + ' related citations</div>': ''
                        showOtherResources.append(
                        '<div>' + relatedCitations + relatedSubjects + '</div>');
                    });
                }).fail(function (jqXHR, textStatus, errorThrown) {
                    console.log(textStatus);
                });
            });
            $('#showOtherResources').children('form').each(function () {
                var url = $(this).attr('action');
                $.get(url, $(this).serialize(), function (data) {
                    var showOtherResources = $("#listOtherResources");
                    var dataArray = data.results.bindings;
                    if (! jQuery.isArray(dataArray)) dataArray =[dataArray];
                    $.each(dataArray, function (currentIndex, currentElem) {
                        var relatedResources = 'Resources related to <a href="' + currentElem.uri.value + '">' + currentElem.label.value + '</a> '
                        var relatedSubjects = (currentElem.subjects) ? '<div class="indent">' + currentElem.subjects.value + ' related subjects</div>': ''
                        var relatedCitations = (currentElem.citations) ? '<div class="indent">' + currentElem.citations.value + ' related citations</div>': ''
                        showOtherResources.append(
                        '<div>' + relatedResources + relatedCitations + relatedSubjects + '</div>');
                    });
                }).fail(function (jqXHR, textStatus, errorThrown) {
                    console.log(textStatus);
                });
            });
            $('#getMoreLinkedData').one("click", function (e) {
                $('#showMoreResources').children('form').each(function () {
                    var url = $(this).attr('action');
                    $.get(url, $(this).serialize(), function (data) {
                        var showOtherResources = $("#showMoreResources");
                        var dataArray = data.results.bindings;
                        if (! jQuery.isArray(dataArray)) dataArray =[dataArray];
                        $.each(dataArray, function (currentIndex, currentElem) {
                            var relatedResources = 'Resources related to <a href="' + currentElem.uri.value + '">' + currentElem.label.value + '</a> '
                            var relatedSubjects = (currentElem.subjects) ? '<div class="indent">' + currentElem.subjects.value + ' related subjects</div>': ''
                            var relatedCitations = (currentElem.citations) ? '<div class="indent">' + currentElem.citations.value + ' related citations</div>': ''
                            showOtherResources.append(
                            '<div>' + relatedResources + relatedCitations + relatedSubjects + '</div>');
                        });
                    }).fail(function (jqXHR, textStatus, errorThrown) {
                        console.log(textStatus);
                    });
                });
            });
});