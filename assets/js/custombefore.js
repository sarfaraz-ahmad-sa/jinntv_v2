jQuery(document).ready(function () {


  /*
   *  Front Slider hover function
   */
  var isChrome = /Chrome/.test(navigator.userAgent) && /Google Inc/.test(navigator.vendor);
  var video_this = null;
  var header_title_img = null;
  $("#myCarousel").find(".carousel-item").hover(function () {
    video_this = $(this).find("video");
    header_title_img = $(this).find("#header-title-image").find("img");
	  
	    video_this.on('play', function (e) {
    $("#myCarousel").carousel('pause');
});
video_this.on('stop pause ended', function (e) {
    $("#myCarousel").carousel();
	video_this.next().fadeIn();
      header_title_img.fadeIn();
	});
	  
    if (!!video_this && video_this.length != null && video_this.length == 1) {
      let context = new AudioContext();
       //$('#myCarousel').carousel('pause');
      if (isChrome) {

        if (context.state != 'running') {
          video_this.get(0).muted = true;
        } else {
          video_this.get(0).muted = false;
        }
      }
      video_this.next().fadeOut();
      header_title_img.fadeOut();
      var playPromise = video_this.get(0).play();
    }
  }, function () {
    if (!!video_this && video_this.length != null && video_this.length == 1) {
      if (video_this.get(0).pause()) {
        video_this.get(0).pause();
      }
      video_this.next().fadeIn();
      header_title_img.fadeIn();

    }
	   
  });


  /*
   *  Video hover function
   */

  var video = null;
  
  $(".on-item-hover").hover(
    function () {
      video = $(this).children("video");
	
      if (!!video && video.length != null && video.length == 1) {
        if (isChrome) {
          let context = new AudioContext();
          if (context.state != 'running') {
         video.get(0).muted = true;
          } else {
			    video.get(0).muted = false;
			  var str = $("#audio_check"). val();
			  if(str=="running")
			  {
       video.get(0).muted = false;
			  }
			  else
			  {
				 video.get(0).muted = true;  
			  }
	
		   
          }
        }
      //  
		
		    timeout =   setTimeout(function() {  
			     video.attr('style', ' opacity:1;');
				     video.next().fadeOut();
			   
			 
			   video.get(0).play();  
			
			  $('.imgnumber').attr('style', 'display:none; position:absolute; top:0%');
			}, 2000);
		  
		  

       
      }
    }, function () {
      if (!!video && video.length != null && video.length == 1) {
        video.get(0).pause();
        video.next().fadeIn(120);
		   clearTimeout(timeout);
		     //clearTimeout(timeout1);
			 // $("#audio_check"). val('stop');
			   var img_ids = $("#playing_identity"). val();
			
			//	$(this).children("video").hide();
		     $('.imgnumber').attr('style', ' position:absolute; top:0%');
		    video.attr('style', ' opacity:0;');
		    video.get(0).muted = true;
      }
    });
	
	



  
 var video1 = null;
  $(".ad_type1").hover(
    function () {
		
		   video1 = $(this).children("video");
		if($(this).children("video").length != 0)

			{
			img = $(this).children("img");
					img.attr('style', 'display:none');
			}

	  	 $(this).children("video").show();
      if (!!video1 && video1.length != null && video1.length == 1) {
        if (isChrome) {
          let context = new AudioContext();
          if (context.state != 'running') {
            video1.get(0).muted = true;
          } else {
            video1.get(0).muted = false;
          }
        }
        video1.next().fadeOut();
        var playPromise = video1.get(0).play();
      }
    }, function () {
      if (!!video1 && video1.length != null && video1.length == 1) {
        video1.get(0).pause();
        video1.next().fadeIn(120);
		$(this).children("video").hide();
		img = $(this).children("img");
		img.attr('style', '');
		     video1.get(0).muted = true;
      }
    });
	
	
	 var video2 = null;


  $(".ad_type2").hover(
    function () {
		 video2 = $(this).children("video");
		if($(this).children("video").length != 0)

			{
			img = $(this).children("img");
					img.attr('style', 'display:none');
			}
	  	 $(this).children("video").show();
      if (!!video2 && video2.length != null && video2.length == 1) {
        if (isChrome) {
          let context = new AudioContext();
          if (context.state != 'running') {
            video2.get(0).muted = true;
          } else {
            video2.get(0).muted = false;
          }
        }
        video2.next().fadeOut();
        var playPromise = video2.get(0).play();
      }
    }, function () {
      if (!!video2 && video2.length != null && video2.length == 1) {
        video2.get(0).pause();
        video2.next().fadeIn(120);
		$(this).children("video").hide();
		img = $(this).children("img");
		img.attr('style', '');
		     video2.get(0).muted = true;
      }
    });
	
   var video3 = null;
  $(".ad_type3").hover(
    function () {
		
		 video3 = $(this).children("video");
		if($(this).children("video").length != 0)

			{
			img = $(this).children("img");
					img.attr('style', 'display:none');
			}
	  	  	 $(this).children("video").show();
      if (!!video3 && video.length != null && video3.length == 1) {
        if (isChrome) {
          let context = new AudioContext();
          if (context.state != 'running') {
            video3.get(0).muted = true;
          } else {
            video3.get(0).muted = false;
          }
        }
        video3.next().fadeOut();
        var playPromise = video3.get(0).play();
      }
    }, function () {
      if (!!video3 && video3.length != null && video3.length == 1) {
        video3.get(0).pause();
        video3.next().fadeIn(120);
		$(this).children("video").hide();
		img = $(this).children("img");
		img.attr('style', '');
		     video3.get(0).muted = true;
      }
    });

  /*
   *  Frontpage scroll header hide and show
   *   check for mobile agent
   */

  /*  if (!(navigator.userAgent.indexOf("JinnTV") != -1)) {
      $(window).scroll($.debounce(550, true, function () {
        $('header').show();
      }));
  
      $(window).scroll($.debounce(550, function () {
        var scroll = $(window).scrollTop();
        if (scroll == 0 && scroll < 10) {
          $("header").show();
        } else {
          $("header").hide();
        }
  
      }));
    }*/




  /*
   *  Frontslider carousel
   */

  var isMobile = {
    Mobile: function () {
      return navigator.userAgent.indexOf("JinnTV") != -1;
    },
    any: function () {
      return (isMobile.Mobile());
    }
  };

  $('#myCarousel').carousel({
    pause: "hover",
    interval: isMobile.any() ? false : 5000
  });




  /*
   *  Carousel Swipe Functionality
   */


  $("#myCarousel").on("touchstart", function (event) {
    var xClick = event.originalEvent.touches[0].pageX;
    $(this).one("touchmove", function (event) {
      var xMove = event.originalEvent.touches[0].pageX;
      if (Math.floor(xClick - xMove) > 5) {
        $(this).carousel('next');
        if ($(event.target).data('toggle') !== 'popover'
          && $(event.target).parents('.popover.in').length === 0) {
          $('[data-toggle="popover"]').popover('hide');
        }
      }
      else if (Math.floor(xClick - xMove) < -5) {
        $(this).carousel('prev');
        if ($(event.target).data('toggle') !== 'popover'
          && $(event.target).parents('.popover.in').length === 0) {
          $('[data-toggle="popover"]').popover('hide');
        }
      }
    });
    $("#myCarousel").on("touchend", function () {
      $(this).off("touchmove");
    });
  });




  /*
   *  Weekly schedule hover modal
   */

  // $("#weekly-schedule-modal").hover(function () {
  //   $('#schedule-popup').modal({
  //     show: true,
  //     backdrop: true
  //   })
  // });


  /*
   *   Frontslider carousel each item iterator
   */

  $(".carousel-item").each(function () {
    var carousel_item_this = $(this);
    var socialShareHtml = carousel_item_this.find("#socialShare-popover-content").html();

    if (navigator.userAgent.indexOf("JinnTV") != -1) {
      carousel_item_this.find(".socialShare").click(function (e) {
        e.preventDefault();
        var social_share_this = $(this);
        var title = social_share_this.parent().prev().find(".header-content").find("h1").text();
        var href = social_share_this.parent().children(':first-child').attr("href");
        window.location.href = document.URL + 'mobile-share?link=' + href + '&title=' + title;
      });
    } else {
      carousel_item_this.find(".socialShare").popover({
        placement: function (context, src) {
          $(context).addClass('share-popover');
          return "bottom";
        },
        html: true,
        content: function () {
          return socialShareHtml;
        }
      }).on('show.bs.popover', function () {
        $("#myCarousel").carousel('pause');
      }).on('hidden.bs.popover', function () {
        $("#myCarousel").carousel('cycle');
      });
    }



    var playlistParseJson;
    carousel_item_this.find("#add-playlist").click(function (e) {
															
      e.preventDefault();
      var add_playlist_this = $(this);
      var playlistHtml = carousel_item_this.find("#addPlaylist-popover-content").html();
      var video_id = add_playlist_this.next().find("#frontslider_video_id").val();

      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data:  "usersession",
       
        success: function (response) {
		
		
          playlistParseJson = jQuery.parseJSON(response);
		 
          if (response && playlistParseJson.message == 1) {

            jQuery.ajax({
              url: jinntvajax.ajax_url,
              type: 'post',
              data: "videos_id="+ video_id,
              
               dataType: 'html',
              success: function (responseHtml) {
			
                if (responseHtml) {
                  add_playlist_this.next().find("#main_wrapper_add_playlist").remove();
                  add_playlist_this.next().append(responseHtml);

                  carousel_item_this.find("#add-playlist").popover({
                    placement: function (context, src) {
                      $(context).addClass('playlist-popover');
                      return "bottom";
                    },
                    html: true,
                    content: function () {
                      return add_playlist_this.next().html();
                    }
                  }).on('show.bs.popover', function () {
                    add_playlist_this.addClass("close-playlist");
                    $("#myCarousel").carousel('pause');
                  }).on('hidden.bs.popover', function () {
                    $("#myCarousel").carousel('cycle');
                    add_playlist_this.removeClass("close-playlist");
                  }).popover('toggle');
                }
              }
            });


          } else {
            window.location.href = "login.php";
          }
        }
      });

      if (!$(this).is(e.target)) {
        $(this).popover('hide');
        $("#myCarousel").carousel('pause');
      }

      $(document).find(".playlist-popover").hover(function () {
        $("#myCarousel").carousel('pause');
      }, function () {
        $("#myCarousel").carousel('cycle');
      });

      $(document).on("click", "#add_playlaylist_text", function () {
        $("#myCarousel").carousel('pause');
      });
    }); //add playlist click ends

    // close all popover on click carousel-indicators
    carousel_item_this.parent().prev().click(function (e) {
      if ($(e.target).data('toggle') !== 'popover'
        && $(e.target).parents('.popover.in').length === 0) {
        $('[data-toggle="popover"]').popover('hide');
      }
    });

  }); // carousel item each function ends




  /*
   *  Add playlist function front slider
   */


  $(document).on("click", '#add_playlist_btn', function () {
    var add_playlist_btn_this = $(this);
    var addPlaylistValue = add_playlist_btn_this.parent().find("#add_playlaylist_text").val();
    var frontslider_video_id = add_playlist_btn_this.parent().parent().parent().find("#frontslider_video_id").val();
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';



    if (addPlaylistValue) {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'add_playlist',
          front_name: addPlaylistValue,
          video_id: frontslider_video_id
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            add_playlist_btn_this.parent().parent().find("#list_playlist").append(responseMessage.html);
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
            add_playlist_btn_this.parent().find("#add_playlaylist_text").val('');
          }
        }
      });
    } else {
      $('#AlertModal').on('show.bs.modal', function () {
        var modal = $(this);
        modal.find('.modal-title').html('<img src="' + info_icon_url + '" width="20" class="mr-2" alt="" />Error');
        modal.find('.modal-body').text('Please Enter Playlist Name')
      });
      $('#AlertModal').modal('show');
    }
  });




  /*
   *  Watch later functionality
   */

  $(document).on("change", '#watch_later', function () {
    var frontslider_video_id = $(this).parent().parent().parent().parent().find("#frontslider_video_id").val();
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';

    if ($(this).is(':checked')) {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'watch_later',
          video_id_watchlater: frontslider_video_id
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
          }
        }
      });
    }
    else {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'remove_watch_later',
          video_id_watchlaters: frontslider_video_id
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
          }
        }
      });
    }
  });


  /*
   * List playlist on checkbox checked
   */

  $(document).on("change", "#playlist_checkbox", function () {
    var playlist_id = $(this).next().next().val();
    var playlist_name = $(this).next().text();
    var frontslider_video_id = $(this).parent().parent().parent().parent().find("#frontslider_video_id").val();
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';

    if ($(this).is(':checked')) {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'add_video_playlist',
          playlist_id: playlist_id,
          video_id: frontslider_video_id
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
          }
        }
      });
    }
    else {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'remove_video_playlist',
          playlist_ids: playlist_id,
          video_ids: frontslider_video_id
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
          }
        }
      });
    }
  });


  /*
   *  ===================== Owl Carousel =======================
   */

  




 
  /*
   * ==============================  Video Detail Page ===========================
   */

  var videoDetailSocialShareHtml = $("#videoDetailSocialShare-popover-content").html();

  if (navigator.userAgent.indexOf("JinnTV") != -1) {
    $(".videoDetailSocialShare").click(function (e) {
      e.preventDefault();
      var videoDetailSocialShare_this = $(this);
      var title = $(document).find(".carousal-sec").find(".container").find(".detail-season-heading").text();
      var href = document.URL;
      window.location.href = document.location.origin + '/mobile-share?link=' + href + '&title=' + title;
    });
  } else {
    $(".videoDetailSocialShare").popover({
      placement: function (context, src) {
        $(context).addClass('video-detail-share-popover');
        return "bottom";
      },
      html: true,
      content: function () {
        return videoDetailSocialShareHtml;
      }
    });
  }



  var videoDetailPlaylistParseJson;
  $("#video-detail-add-playlist").click(function (e) {
												
    e.preventDefault();
    var video_detail_add_playlist_this = $(this);
    var video_id = video_detail_add_playlist_this.next().find("#video_detail_id").val();

  
  
  
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data:  "usersession",
       
        success: function (response) {
        videoDetailPlaylistParseJson = jQuery.parseJSON(response);
		
		  if (response && videoDetailPlaylistParseJson.message == 1) {

            jQuery.ajax({
              url: jinntvajax.ajax_url,
              type: 'post',
              data: "detail_video_id="+ video_id,
              
               dataType: 'html',
              success: function (responseHtml) {
			
                if (responseHtml) {
		
		
		

                video_detail_add_playlist_this.next().find("#main_wrapper_video_detail_add_playlist").remove();
                video_detail_add_playlist_this.next().append(responseHtml);

                $("#video-detail-add-playlist").popover({
                  placement: function (context, src) {
                    $(context).addClass('video-detail-playlist-popover');
                    return "bottom";
                  },
                  html: true,
                  content: function () {
                    return video_detail_add_playlist_this.next().html();
                  }
                }).on('show.bs.popover', function () {
                  video_detail_add_playlist_this.addClass("close-playlist");
                }).on('hidden.bs.popover', function () {
                  video_detail_add_playlist_this.removeClass("close-playlist");
                }).popover('toggle');
              }
            }
          });
        } else {
          window.location.href = "login.php";
        }
      }
    });

    if (!$(this).is(e.target)) {
      $(this).popover('hide');
    }

  }); //add playlist click ends



  /*
   *  Video Detail Add playlist function
   */


  $(document).on("click", '#video_detail_add_playlist_btn', function () {
    var video_detail_add_playlist_btn_this = $(this);
    var videoDetailAddPlaylistValue = video_detail_add_playlist_btn_this.parent().find("#video_detail_add_playlaylist_text").val();
    var videoDetailId = video_detail_add_playlist_btn_this.parent().parent().parent().find("#video_detail_id").val();
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';

    if (videoDetailAddPlaylistValue) {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'add_playlist',
          name_playlist: videoDetailAddPlaylistValue,
          video_id: videoDetailId
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
			 
            video_detail_add_playlist_btn_this.parent().parent().find("#video_detail_list_playlist").append(responseMessage.html);
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
            video_detail_add_playlist_btn_this.parent().find("#video_detail_add_playlaylist_text").val('');
          }
        }
      });
    } else {
      $('#AlertModal').on('show.bs.modal', function () {
        var modal = $(this);
        modal.find('.modal-title').html('<img src="' + info_icon_url + '" width="20" class="mr-2" alt="" />Error');
        modal.find('.modal-body').text('Please Enter Playlist Name')
      });
      $('#AlertModal').modal('show');
    }
  });


  /*
   * Video Detail Watch later functionality
   */

  $(document).on("change", '#video_detail_watch_later', function () {
    var videoDetailId = $(this).parent().parent().parent().parent().find("#video_detail_id").val();
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';

    if ($(this).is(':checked')) {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'watch_later',
          video_id_watchlater: videoDetailId
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
          }
        }
      });
    }
    else {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'remove_watch_later',
          video_id_watchlaters: videoDetailId
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
          }
        }
      });
    }
  });



  /*
   * Video Detail List playlist on checkbox checked
   */

  $(document).on("change", "#video_detail_list_playlist #playlist_checkbox", function () {
    var playlist_id = $(this).next().next().val();
    var playlist_name = $(this).next().text();

    var video_detail_id = $(this).parent().parent().parent().parent().find("#video_detail_id").val();
		
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';

    if ($(this).is(':checked')) {
		
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'add_video_playlist',
          playlist_id: playlist_id,
          video_id: video_detail_id
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
          }
        }
      });
    }
    else {
	
      jQuery.ajax({
				  
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'remove_video_playlist',
          playlist_ids: playlist_id,
          video_ids: video_detail_id
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
          }
        }
      });
    }
  });

  /*
   * ============================ Video Detail Page Ends =============================
   */




  /*
   * ======================= My Videos Page  =========================
   */


  /*
   *  My playlist button functionality on My Videos Page
   */


  $("#my_videos_playlist").click(function (e) {
    e.preventDefault();
    var my_videos_playlist_this = $(this);
    my_videos_playlist_this.popover({
      placement: function (context, src) {
        $(context).addClass('my-videos-playlist-popover');
        return "bottom";
      },
      html: true,
      content: function () {
        return my_videos_playlist_this.next().html();
      }
    }).on('show.bs.popover', function () {
      my_videos_playlist_this.addClass("close-playlist");
    }).on('hidden.bs.popover', function () {
      my_videos_playlist_this.removeClass("close-playlist");
    }).popover('toggle');
  });



  /*
   *  Add playlist button functionality on My Videos Page
   */


  $("#myvideos_playlist_wrapper").parent().parent().hide();

  $(document).on("click", "#myvideos_add_playlist_btn", function (e) {
														  
    e.preventDefault();
    var myvideos_add_playlist_btn_this = $(this);
    var myvideos_add_playlaylist_text = myvideos_add_playlist_btn_this.parent().find("#myvideos_add_playlaylist_text").val();
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';

    if (myvideos_add_playlaylist_text) {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'myvideos_add_playlist',
          name: myvideos_add_playlaylist_text,
        },
        success: function (response) {
				  
          responseMessage = jQuery.parseJSON(response);
	
          if (responseMessage) {
		
            $("#myvideos_playlist_wrapper").prepend(responseMessage.html);
			
            $("#myvideos_playlist_wrapper").parent().parent().show();
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
            myvideos_add_playlist_btn_this.parent().find("#myvideos_add_playlaylist_text").val('');
          }
        }
      });
    } else {
      alert("Please Enter Playlist Name");
    }

  });


  /*
   *  Edit Playlist button  functionality on My Videos Page
   *    Make a function
   */

  function myVideosEditPlaylist() {
    $(document).on("click", "#myvideos_edit_playlist", function (e) {
      e.preventDefault();
      var myvideos_edit_playlist_this = $(this);
      var playlist_text = myvideos_edit_playlist_this.parent().parent().text();
      var playlist_text = $.trim(playlist_text);
      myvideos_edit_playlist_this.parent().parent().hide();
      myvideos_edit_playlist_this.parent().parent().parent().prepend('<input type="text" name="edit_playlist_text" id="edit_playlist_text" class="form-control edit_playlist_text" value="' + playlist_text + '"/>');
      myvideos_edit_playlist_this.parent().parent().after('<button type="button" id="save_myvideos_playlist" class="btn solid-btn my-2 mr-2">Save</button><button type="button" id="cancel_myvideos_playlist" class="btn bordered-btn my-2">Cancel</button>');
      myvideos_edit_playlist_this.off(e);
    });
  }


  myVideosEditPlaylist();



  /*
   *  Save Button Playlist on My Videos Page
   */


  $(document).on("click", "#save_myvideos_playlist", function (e) {
    e.preventDefault();
    var save_myvideos_playlist_this = $(this);
	
    var myvideos_playlist_name = save_myvideos_playlist_this.prev().prev().prev().prev().prev().val();

    var myvideos_playlist_id = save_myvideos_playlist_this.prev().prev().prev().val();
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';

    if (myvideos_playlist_name != "") {
      save_myvideos_playlist_this.prev().prev().prev().remove();
      var child1 = save_myvideos_playlist_this.prev().children(1);
	
      var child2 = save_myvideos_playlist_this.prev().children(2);
      save_myvideos_playlist_this.prev().html('');
      save_myvideos_playlist_this.prev().prepend(myvideos_playlist_name);
      save_myvideos_playlist_this.prev().append(child1);
      save_myvideos_playlist_this.prev().append(child2);
      save_myvideos_playlist_this.prev().show();


      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'update_playlist',
          update_id: myvideos_playlist_id,
          update_name: myvideos_playlist_name
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
            save_myvideos_playlist_this.next().remove();
            save_myvideos_playlist_this.remove();
edit_playlist_text.remove();
            save_myvideos_playlist_this.prev().eq(0).on('click', myVideosEditPlaylist());
          }
        }
      });
    }
    else {
      $('#AlertModal').on('show.bs.modal', function () {
        var modal = $(this);
        modal.find('.modal-title').html('<img src="' + info_icon_url + '" width="20" class="mr-2" alt="" />Error');
        modal.find('.modal-body').text("Please Enter Playlist Text")
      });
      $('#AlertModal').modal('show');
    }


  });






  /*
   *  Cancel Button Playlist on My Videos Page
   */


  $(document).on("click", "#cancel_myvideos_playlist", function (e) {
    e.preventDefault();
    var cancel_myvideos_playlist_this = $(this);
    cancel_myvideos_playlist_this.prev().prev().prev().prev().remove();
    cancel_myvideos_playlist_this.prev().prev().show();
    cancel_myvideos_playlist_this.prev().prev().eq(0).on('click', myVideosEditPlaylist());
    cancel_myvideos_playlist_this.prev().remove();
    cancel_myvideos_playlist_this.remove();
  });



  /*
   *  Show confirm modal popup on my videos delete playlist
   */


  var myvideos_delete_playlist_this = null;
  $(document).on("click", "#myvideos_delete_playlist", function (e) {
																
    e.preventDefault();
    myvideos_delete_playlist_this = $(this);
	//    var myvideos_playlist_id = myvideos_delete_playlist_this.parent().parent().prev().val();
	//	alert(myvideos_playlist_id);
    var myvideos_playlist_id = myvideos_delete_playlist_this.parent().parent().prev().prev().val();

    var myvideos_playlist_name = $.trim(myvideos_delete_playlist_this.parent().parent().text());
    var myvideos_playlist_element_count = myvideos_delete_playlist_this.parent().parent().parent().parent().find("div").length;

    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';

    $('#AlertModal').on('show.bs.modal', function () {
      var modal = $(this);
      modal.find('.modal-title').html('<img src="' + info_icon_url + '" width="20" class="mr-2" alt="" />Confirm');
      modal.find('.modal-body').html('Are you sure you want to delete ' + myvideos_playlist_name + '<br><br><div class="modal-bottom-btn"><input type="hidden" name="myvideos_playlist_id" id="myvideos_playlist_id" value="' + myvideos_playlist_id + '"/><input type="hidden" name="myvideos_playlist_element_count" id="myvideos_playlist_element_count" value="' + myvideos_playlist_element_count + '"/><button type="button" id="cancel_delete_playlist" class="btn gray-bordered-btn mt-2 mr-2">Cancel</button><button type="button" id="ok_delete_playlist" class="btn solid-btn mt-2">OK</button></div>');
    });
    $('#AlertModal').modal('show');


  });

  /*
   *  On Click cancel hide the modal
   */

  $(document).on("click", "#cancel_delete_playlist", function () {
    $('#AlertModal').modal('hide');
  });

  /*
   *  On Click ok delete playlist
   */

  /*
   *  Delete Button Playlist on My Videos Page
   */

  $(document).on("click", "#ok_delete_playlist", function (e) {
    e.preventDefault();
	
    var ok_delete_playlist_this = $(this);



  var myvideos_playlist_id = ok_delete_playlist_this.prev().prev().prev().val();
  	
    var myvideos_playlist_element_count = ok_delete_playlist_this.prev().prev().val();
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';


    jQuery.ajax({
      url: jinntvajax.ajax_url,
      type: 'post',
      data: {
        action: 'delete_playlist',
        delete_id: myvideos_playlist_id
      },
      success: function (response) {
        responseMessage = jQuery.parseJSON(response);
        if (responseMessage) {
          $('#AlertModal').modal('hide');
          var showPopup = true;
          $('#AlertModal').on('hidden.bs.modal', function () {
            if (showPopup) {
              $('#AlertModal').modal('show');
              showPopup = false;
            }
          });
          $('#AlertModal').on('show.bs.modal', function () {
            var modal = $(this);
            modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
            modal.find('.modal-body').text(responseMessage.message)
          });
          if (myvideos_delete_playlist_this) {
            if (myvideos_playlist_element_count == 1) {
              myvideos_delete_playlist_this.parent().parent().parent().parent().parent().hide();
			  location.reload();
            }
           myvideos_delete_playlist_this.parent().parent().parent().remove();
          }

        }
      }
    });
  });

  /*
   * =============================== My Videos Page Ends ========================
   */




  /*
   * =============================== Subscribers ========================
   */


  /*
   * Global subscribe function
   */

  $(document).on("click", "#subscribe_btn", function (e) {
    e.preventDefault();
    var subscribe_btn_this = $(this);
    var category_id = subscribe_btn_this.prev().val();
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';

    jQuery.ajax({
      url: jinntvajax.ajax_url,
      type: 'post',
      data: {
        action: 'subscribe',
        category_id: category_id
      },
      success: function (response) {
        responseMessage = jQuery.parseJSON(response);
        if (responseMessage) {
          if (responseMessage.message) {
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
          }
          if (responseMessage.errormessage) {
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + info_icon_url + '" width="20" class="mr-2" alt="" />Info');
              modal.find('.modal-body').text(responseMessage.errormessage)
            });
            $('#AlertModal').modal('show');
          }
        }
      }
    });

  });

  /*
   *  Profile subscribe or unsubscribe checkboxes
   */

  $(document).on("click", "#myprofile_checkbox", function (e) {
    e.preventDefault();
    var myprofile_checkbox_this = $(this);
    var category_id = myprofile_checkbox_this.prev().val();
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';

    if (myprofile_checkbox_this.is(':checked')) {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'myprofile_subscribe',
          category_id: category_id
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            myprofile_checkbox_this.prop('checked', true);
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
          }
        }
      });
    } else {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'myprofile_unsubscribe',
          category_id: category_id
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            myprofile_checkbox_this.prop('checked', false);
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message)
            });
            $('#AlertModal').modal('show');
          }
        }
      });
    }

  });



  /*
   *  Confirm popup modal appear to confirm ok or cancel
   */

  var myvideos_delete_playlist_item_this = null;
  $(document).on("click", "#myvideos_delete_playlist_item", function (e) {
    e.preventDefault();

    myvideos_delete_playlist_item_this = $(this);
    var video_id = myvideos_delete_playlist_item_this.prev().val();
    var playlist_id = myvideos_delete_playlist_item_this.parent().parent().parent().parent().parent().parent().find("#myvideos_playlist_id").val();
    var myvideos_count = myvideos_delete_playlist_item_this.parent().parent().parent().parent().parent().parent().find(".owl-item").length;
    var myvideos_item_name = myvideos_delete_playlist_item_this.next().next().next().next().find(".item-main-heading").text();
    var myvideos_playlist_name = myvideos_delete_playlist_item_this.parent().parent().parent().parent().parent().parent().find("#myvideos_playlist_name").text();
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';

    $('#AlertModal').on('show.bs.modal', function () {
      var modal = $(this);
      modal.find('.modal-title').html('<img src="' + info_icon_url + '" width="20" class="mr-2" alt="" />Confirm');
      modal.find('.modal-body').html('Are you sure you want to delete ' + myvideos_item_name + ' from ' + myvideos_playlist_name + '<br><br><div class="modal-bottom-btn"><input type="hidden" name="video_id" id="video_id" value="' + video_id + '"/><input type="hidden" name="playlist_id" id="playlist_id" value="' + playlist_id + '"/><input type="hidden" name="myvideos_count" id="myvideos_count" value="' + myvideos_count + '"/><button type="button" id="cancel_delete_playlist_item" class="btn gray-bordered-btn mt-2 mr-2">Cancel</button><button type="button" id="ok_delete_playlist_item" class="btn solid-btn mt-2">OK</button></div>');
    });
    $('#AlertModal').modal('show');
  });

  /*
   *  On Click cancel hide the modal
   */

  $(document).on("click", "#cancel_delete_playlist_item", function () {
    $('#AlertModal').modal('hide');
  });



  /*
   *  Delete Individual Item in playlist
   */

  $(document).on("click", "#ok_delete_playlist_item", function () {
    var ok_delete_playlist_item_this = $(this);

    var video_id = ok_delete_playlist_item_this.prev().prev().prev().prev().val();
    var playlist_id = ok_delete_playlist_item_this.prev().prev().prev().val();
    var myvideos_count = ok_delete_playlist_item_this.prev().prev().val();
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';


    jQuery.ajax({
      url: jinntvajax.ajax_url,
      type: 'post',
      data: {
        action: 'delete_playlist_item',
        playlist_id: playlist_id,
        video_id: video_id
      },
      success: function (response) {
        responseMessage = jQuery.parseJSON(response);
        if (responseMessage) {
          $('#AlertModal').modal('hide');
          var showPopup = true;
          $('#AlertModal').on('hidden.bs.modal', function () {
            if (showPopup) {
              $('#AlertModal').modal('show');
              showPopup = false;
            }
          });
          $('#AlertModal').on('show.bs.modal', function () {
            var modal = $(this);
            modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
            modal.find('.modal-body').text(responseMessage.message);
          });

          if (myvideos_count == 1) {
            if (myvideos_delete_playlist_item_this) {
              myvideos_delete_playlist_item_this.parent().parent().parent().parent().parent().parent().append(responseMessage.html);
              myvideos_delete_playlist_item_this.parent().parent().parent().parent().parent().remove();
            }
          } else {
            if (myvideos_delete_playlist_item_this) {
              myvideos_delete_playlist_item_this.parent().parent().parent().parent().parent().closest(".owl-carousel").trigger('remove.owl.carousel', myvideos_delete_playlist_item_this.parent().parent().index())
                .trigger('refresh.owl.carousel');
            }
          }
        }
      }
    });
  });


  /*
   * Close Live Notification Popup
   */

  /* $(document).find(".live-popup").find(".close").on("click", function (e) {
     e.preventDefault();
     var live_popup_this = $(this);
     var live_video_id = live_popup_this.prev().val();
 
     jQuery.ajax({
       url: jinntvajax.ajax_url,
       type: 'post',
       data: {
         action: 'close_live_popup',
         live_video_id: live_video_id
       },
       success: function (response) {
 
       }
     });
   });*/



  /*
   *  Add class active on both profile menu or navbar a
   */

  var current_page_url = window.location.pathname;

  if (current_page_url && current_page_url != "/") {

    /*
     *  Add class active on navbar a
     */
    urlRegExp = new RegExp(current_page_url.replace(/\/$/, '') + "$");
    $('.navbar-nav a').each(function () {
      if (urlRegExp.test(this.href.replace(/\/$/, ''))) {
        $(this).addClass('active');
      }
    });


    /*
     *  Profile menu active class
     */

    $('.profile-menu a').each(function () {
      if (urlRegExp.test(this.href.replace(/\/$/, ''))) {
        $(this).addClass('active');
      }
    });
  }




  /*
   * Delete Profile picture functionality
   */

  var delete_profile_picture_this = null;
  $(document).on("click", "#delete_profile_picture", function (e) {
															  
    e.preventDefault();
    delete_profile_picture_this = $(this);
    var attachment_id = delete_profile_picture_this.children(":first").val();
    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';

    $('#AlertModal').on('show.bs.modal', function () {
      var modal = $(this);
      modal.find('.modal-title').html('<img src="' + info_icon_url + '" width="20" class="mr-2" alt="" />Confirm');
      modal.find('.modal-body').html('Are you sure you want to delete profile picture' + '<br><br><div class="modal-bottom-btn"><input type="hidden" name="attachment_id" id="attachment_id" value="' + attachment_id + '"/><button type="button" id="cancel_delete_profile_picture" class="btn gray-bordered-btn mt-2 mr-2">Cancel</button><button type="button" id="ok_delete_profile_picture" class="btn solid-btn mt-2">OK</button></div>');
    });
    $('#AlertModal').modal('show');
  });



  /*
   *  On Click cancel hide the profile picture modal
   */

  $(document).on("click", "#cancel_delete_profile_picture", function () {
    $('#AlertModal').modal('hide');
  });



  /*
   * Ok Delete Profile Picture
   */

  $(document).on("click", "#ok_delete_profile_picture", function () {
    var ok_delete_playlist_item_this = $(this);
    var attachment_id = ok_delete_playlist_item_this.prev().prev().val();
    var success_icon_url =  'assets/images/success-icon.svg';
    var default_avatar_url = 'assets/images/avatar_2x.png';

    if (attachment_id) {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'delete_profile_picture',
          attachment_id: attachment_id
        },
        success: function (response) {
          responseMessage = jQuery.parseJSON(response);
          $('#AlertModal').modal('hide');
          var showPopup = true;
          $('#AlertModal').on('hidden.bs.modal', function () {
            if (showPopup) {
              $('#AlertModal').modal('show');
              showPopup = false;
            }
          });
          $('#AlertModal').on('show.bs.modal', function () {
            var modal = $(this);
            modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
            modal.find('.modal-body').text(responseMessage.message);
          });
          if (delete_profile_picture_this) {
            delete_profile_picture_this.prev().prev().prev().prev().prev().attr("src", default_avatar_url);
            delete_profile_picture_this.hide();
          }
        }
      });
    }
  });




  /*
   *  Delete Individual watch later functionality
   */

  var myvideos_delete_watchlater_item_this = null;
  $(document).on("click", "#myvideos_delete_watchlater_item", function (e) {
    e.preventDefault();
    myvideos_delete_watchlater_item_this = $(this);
    var video_id = myvideos_delete_watchlater_item_this.prev().val();
    var myvideos_count = myvideos_delete_watchlater_item_this.parent().parent().parent().parent().parent().parent().find(".owl-item").length;
    var myvideos_watchlater_item_name = myvideos_delete_watchlater_item_this.next().next().next().next().find(".item-main-heading").text();

    var info_icon_url = window.location.origin + '/assets/images/info-icon.svg';

    $('#AlertModal').on('show.bs.modal', function () {
      var modal = $(this);
      modal.find('.modal-title').html('<img src="' + info_icon_url + '" width="20" class="mr-2" alt="" />Confirm');
      modal.find('.modal-body').html('Are you sure you want to delete ' + myvideos_watchlater_item_name + '<br><br><div class="modal-bottom-btn"><input type="hidden" name="video_id" id="video_id" value="' + video_id + '"/><input type="hidden" name="myvideos_count" id="myvideos_count" value="' + myvideos_count + '"/><button type="button" id="cancel_delete_watchlater_item" class="btn gray-bordered-btn mt-2 mr-2">Cancel</button><button type="button" id="ok_delete_watchlater_item" class="btn solid-btn mt-2">OK</button></div>');
    });
    $('#AlertModal').modal('show');
  });



  /*
   * Cancel Delete Watchlater
   */

  $(document).on("click", "#cancel_delete_watchlater_item", function () {
    $('#AlertModal').modal('hide');
  });



  /*
   *  Delete Individual Item in Watchlater
   */

  $(document).on("click", "#ok_delete_watchlater_item", function () {
    var ok_delete_watchlater_item_this = $(this);

    var video_id = ok_delete_watchlater_item_this.prev().prev().prev().val();
    var myvideos_count = ok_delete_watchlater_item_this.prev().prev().val();
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';


    jQuery.ajax({
      url: jinntvajax.ajax_url,
      type: 'post',
      data: {
        action: 'delete_watchlater_item',
        video_id: video_id
      },
      success: function (response) {
        responseMessage = jQuery.parseJSON(response);
        if (responseMessage) {
          $('#AlertModal').modal('hide');
          var showPopup = true;
          $('#AlertModal').on('hidden.bs.modal', function () {
            if (showPopup) {
              $('#AlertModal').modal('show');
              showPopup = false;
            }
          });
          $('#AlertModal').on('show.bs.modal', function () {
            var modal = $(this);
            modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
            modal.find('.modal-body').text(responseMessage.message);
          });

          if (myvideos_count == 1) {
            if (myvideos_delete_watchlater_item_this) {
              myvideos_delete_watchlater_item_this.parent().parent().parent().parent().parent().parent().parent().remove();
            }
          } else {
            if (myvideos_delete_watchlater_item_this) {
              myvideos_delete_watchlater_item_this.parent().parent().parent().parent().parent().closest(".owl-carousel").trigger('remove.owl.carousel', myvideos_delete_watchlater_item_this.parent().parent().index())
                .trigger('refresh.owl.carousel');
            }
          }

        }
      }
    });
  });


  /*
   *  Profile picture change function
   */

 

  //Search hide class onfocus
  /*$("#showhideSearch").focusin(function () {
    $(this).addClass('showSearch');
  });
  $("#showhideSearch").focusout(function () {
    $(this).removeClass('showSearch');
  });*/

  // alternative focusin or out
  var searchisOpen = false;
  $("#search-icon").click(function () {
									
    if (searchisOpen == false) {
      $(this).parent().addClass('showSearch');
      $("#showhideSearch").focus();
      searchisOpen = true;
    } else {
      $(this).parent().removeClass('showSearch');
      $("#showhideSearch").focusout();
      searchisOpen = false;
    }
  });

  $("#search-icon").mouseup(function () {
    return false;
  });

  $("#showhideSearch").mouseup(function () {
    return false;
  });

  $(document).mouseup(function () {
    if (searchisOpen == true) {
      $('#search-icon').click();
    }
  });

  if ($("#showhideSearch").hasClass("showSearch")) {
    $("#search").keydown(function () {
								   
      if ($(this).val().length == 1 || $(this).val().length == 0) {
        // Enable submit button
        $('#search-icon').click();
      }
    });
  }



  var searchRequest;
  $('.search-autocomplete').autoComplete({
										
    minChars: 2,
	dataType: 'json',
    source: function (term, suggest) {
      try { searchRequest.abort(); } catch (e) { }
      
			
	 
      
	 searchRequest=  $.ajax(
        {
            url:jinntvajax.ajax_url ,
            dataType: "json",
            data:
            {
                search: term,
            },
            success: function (data)
            {
                
			
			
				 var choices = data.data;
                  
                    var suggestions = [];
                    for (i=0;i<choices.length;i++)
                        if (~choices[i].toLowerCase().indexOf(term)) suggestions.push(choices[i]);
       suggest(suggestions);
            }
        });
	  
	  
	  
	  
	  
	  
	
    }
  });



  /*
   *  Problem Listing Starts
   */

  $("#question-icon").click(function (e) {
									
    e.preventDefault();
    $('#problemModal').modal('show');
  });

  function isAtLeastOnceChecked() {
    return ($(document).find("#problem_list").find('input[type="checkbox"]:checked').length);
  }

  $(document).find("#problem_list").find('input[type="checkbox"]').change(function () {
    var problem_list_checkbox = $(this);

    if (problem_list_checkbox.is(':checked')) {
      if (isAtLeastOnceChecked() == 1) {
        $("#problemModal").find(".modal-body").find("#problem_list_more_details").remove();
        $("#problemModal").find(".modal-body").append('<div class="problem_list_more_details" id="problem_list_more_details"><p>Any more details? (optional)</p><textarea id="problem_list_textarea" rows="4" cols="30"></textarea><br/><button type="button" id="problem_list_submit_btn" class="btn btn-danger subscribe-btn mt-2">Submit Report</button></div>');
      }

    } else if (isAtLeastOnceChecked() == 0) {
      $("#problemModal").find(".modal-body").find("#problem_list_more_details").remove();
    }

  });

  $(document).on('hidden.bs.modal', function (e) {
    var problemModal = $("#problemModal");
    var problemModalfindProblemBody = problemModal.find(".modal-body");
    if (problemModal.attr('data-refresh') == 'true') {
      problemModalfindProblemBody.find("#problem_list li").each(function (index, element) {
        $(this).find('input[type="checkbox"]').prop("checked", false);
        problemModalfindProblemBody.find("#problem_list_more_details").remove();
      });
    }
  });

  var problems_array = [];
  $(document).on("click", "#problem_list_submit_btn", function (e) {
															
    e.preventDefault();
    var problemModal = $("#problemModal");
    var problemModalfindProblemBody = problemModal.find(".modal-body");

    var current_user_id = problemModalfindProblemBody.find("#current_user_id").val();
    var video_id = problemModalfindProblemBody.find("#video_id").val();
    var problem_list_textarea = problemModalfindProblemBody.find("#problem_list_more_details").find("#problem_list_textarea").val();
    var success_icon_url = window.location.origin + '/assets/images/success-icon.svg';

    problemModalfindProblemBody.find("#problem_list li").each(function (index, element) {
      if ($(this).find('input[type="checkbox"]').is(':checked')) {
        problems_array.push($(this).find('input[type="checkbox"]').val());
      }
    });

    if (problems_array) {
      jQuery.ajax({
        url: jinntvajax.ajax_url,
        type: 'post',
        data: {
          action: 'problem_list',
          current_user_id: current_user_id,
          problem_video_id: video_id,
          problems: problems_array,
          description: problem_list_textarea
        },
        success: function (response) {
          problems_array = [];
          responseMessage = jQuery.parseJSON(response);
          if (responseMessage) {
            $('#problemModal').modal('hide');
            $('#AlertModal').on('show.bs.modal', function () {
              var modal = $(this);
              modal.find('.modal-title').html('<img src="' + success_icon_url + '" width="20" class="mr-2" alt="" />Success');
              modal.find('.modal-body').text(responseMessage.message);
            });
            $('#AlertModal').modal('show');
          }
        }
      });
    }
  });

  /*
   *  Problem Listing Ends
   */

  $('[data-toggle="tooltip"]').tooltip();

  //end of the ready function
});

/* Search Field Expand Collapsed */

(function () {

  'use strict';

  var expandSearch = {
    init: function () {

      var _this = this,
        _searchContainers = document.querySelectorAll('.expandSearch');

      for (var _index in _searchContainers) {
        if (typeof _searchContainers[_index] === 'object') {
          _this.searchFunctions(_searchContainers[_index]);
        }
      }

    },

    searchFunctions: function (_thisSearch) {

      var _nodes = _thisSearch.childNodes;

      //a click
      _nodes[3].addEventListener('click', function (e) {
        if (_thisSearch.attributes.class.value.indexOf("showSearch") > -1) {
          _thisSearch.attributes.class.value = 'expandSearch';
        }
        else {
          _thisSearch.attributes.class.value = 'expandSearch showSearch';
        }

        if (!e.preventDefault()) { e.returnValue = false; }
      });

    }

  };

  $(window).on("scroll", function () {
    if ($(window).scrollTop() > 50) {
      $(".navbar").addClass("nav-bg-dark");
    } else {
      //remove the background property so it comes transparent again (defined in your css)
      $(".navbar").removeClass("nav-bg-dark");
    }
  });


  //execute
  expandSearch.init();

}());