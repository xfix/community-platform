$(function() {

	// All external links in new window
	$("a[href^='http']").each(function(){
		if(this.href.indexOf(location.hostname) == -1) {
			$(this).attr('target', '_blank');
		}
	});

	// general autosubmit class
	$('select.autosubmit,input.autosubmit').live('change',function(){
		$(this).parents('form').submit();
	});

	//
	// account page
	//

	// TODO make this a real widget and being part of the HTML code, there cant be text in the JavaScript lib
	$('a.removeLanguage').click(function() {
		return confirm("Are you sure you want to remove this language?");
	});

	// Gravatar
	$('div#set_gravatar_email').hide();
	$('a#add_gravatar_email').click(function() {
		$('div#set_gravatar_email').show();
	});







	$('a.vote_link').live('click',function(e){
		e.preventDefault();
		var parent = $(this).parent();
		$.ajax({
			url: $(this).attr('href'),
			beforeSend: function(xhr) {
				parent.html('<img src="/static/images/ajax-loader.gif"/>');
			},
			success: function(data) {
				parent.html(data);
			}
		});
	});

	$('a.comment_reply_link').live('click', function(e){
		e.preventDefault();
		$(this).next('.comment_reply_cancel_link').fadeIn();
		$(this).parent().parent().children('.comment_reply').fadeIn();
		$(this).hide();
	});

	$('a.comment_reply_cancel_link').live('click', function(e){
		e.preventDefault();
		$(this).prev('.comment_reply_link').fadeIn();
		$(this).parent().parent().children('.comment_reply').fadeOut();
		$(this).hide();
	});

	$('a.comment_expand_link').live('click', function(e){
		e.preventDefault();
		$(this).parent().html($(this).next('.comment_expanded_content').html());
	});

	$('.close-warning, .close-wrong').live('click', function (e){
		console.log('success');
		$(this).parent().fadeOut();
	});

	if (typeof(userHasLanguages) != "undefined") {
		if (userHasLanguages) {
			$('#btnAddNewLanguage').show();
			$('#formAddUserLanguage').hide();
			$('table.account-table [id^=update_]').hide();
		}
	}

	$('table.account-table select').each(function() {
		$(this).live('change',function(){
			grade = $('option:selected',this).val();
			language = $(this).attr('id').substring(6);
			href = '?add_user_language=' + language;
			href += '&grade=' + grade;
			$("#update_"+language).fadeIn();
			$("#update_"+language).attr('href', href);
		});
	});

	$('#account-table_ftrLeft').hover(function() {
		$('#gradeReference').fadeIn();
	}, function(){
		$('#gradeReference').fadeOut();
	});

	if(typeof(breadcrumb_right) != "undefined") {
		if (breadcrumb_right == 'language') {
			$('#languageBox').hide();
		}
	}

});

function showFormAddUserLanguage() {
    $('#formAddUserLanguage').fadeIn();
    $('#btnAddNewLanguage').fadeOut();
}

function validateFormAddUserLanguage() {
    selectedLanguage=$('#language_id :selected').text().substring(16,21);
    if ($.inArray(selectedLanguage, userLanguages) != -1) {
        return false;
    }
    return true;
}

function validateFormGravatar() {
    if ($('#gravatar_email').val() == '') {
        $('#error_gravatar_invalid_email').fadeIn();
        return false;
    }
    return true;
}

function validateFormLogin() {
	console.log($('#username'));
	if ($('#username').val() === '' || $('#password').val() === '') {
		$('#invalidForm').fadeIn();
		return false;
	}
	return true;
}

function showLanguageBox() {
	if($('#languageBox').css('display') == 'none') {
		$('#languageBox').slideDown();
		$('#btnChooseLanguage').html('&#9650;');
	} else {
		$('#languageBox').slideUp();
		$('#btnChooseLanguage').html('&#9660;');
	}
	return false;
}
