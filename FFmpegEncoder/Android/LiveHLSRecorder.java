package com.example.ffmpegtest.recorder;

import java.io.File;
import java.io.IOException;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import android.content.Context;
import android.content.Intent;
import android.os.Trace;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;

import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.services.s3.AmazonS3Client;
import com.amazonaws.services.s3.model.ProgressEvent;
import com.example.ffmpegtest.FileUtils;
import com.example.ffmpegtest.HLSFileObserver;
import com.example.ffmpegtest.HLSFileObserver.HLSCallback;
import com.example.ffmpegtest.S3Client;
import com.example.ffmpegtest.S3Client.S3Callback;
import com.example.ffmpegtest.SECRETS;
import com.readystatesoftware.simpl3r.Uploader;
import com.readystatesoftware.simpl3r.Uploader.UploadProgressListener;

public class LiveHLSRecorder extends HLSRecorder{
	private final String TAG = "LiveHLSRecorder";
	private final boolean VERBOSE = false; 						// lots of logging
	private final boolean TRACE = true;							// Enable systrace markers
	private final boolean UPLOAD_TO_S3 = true;					// live uploading
	
	private Context c;
	private String uuid;										// Recording UUID
	private HLSFileObserver observer;							// Must hold reference to observer to continue receiving events
	private ExecutorService uploadService;
	
	public static final String INTENT_ACTION = "HLS";			// Intent action broadcast to LocalBroadcastManager
	public enum HLS_STATUS { OFFLINE, LIVE };
	
	private boolean sentIsLiveBroadcast = false;				// Only send "broadcast is live" intent once per recording
	private int lastSegmentWritten = 0;
	File temp;													// Temporary directory to store .m3u8s for each upload state
	
	// Amazon S3
	private final String S3_BUCKET = "openwatch-livestreamer";
	private S3Client s3Client;
	
	public LiveHLSRecorder(Context c){
		super(c);
		s3Client = new S3Client(c, SECRETS.AWS_KEY, SECRETS.AWS_SECRET);
		s3Client.setBucket(S3_BUCKET);
		uploadService = Executors.newSingleThreadExecutor();
		lastSegmentWritten = 0;
		this.c = c;
	}
	
	/**
	 * We'll create a single thread ExecutorService for uploading, and immediately
	 * submit the .ts and .m3u8 jobs in tick-tock fashion.
	 * Currently, the fileObserver callbacks don't return until the entire upload
	 * is complete, which means by the time the first .ts uploads, the the next callback (the .m3u8 write) 
	 * is called when the underlying action has been negated by future (but uncalled) events
	 */
	@Override
	public void startRecording(final String outputDir){
		super.startRecording(outputDir);
		temp = new File(getOutputDirectory(), "temp");	// make temp directory for .m3u8s for each upload state
		temp.mkdirs();
		sentIsLiveBroadcast = false;
		if (!UPLOAD_TO_S3) return;
        observer = new HLSFileObserver(getOutputDirectory().getAbsolutePath(), new HLSCallback(){

			@Override
			public void onSegmentComplete(final String path) {
				lastSegmentWritten++;
				if (VERBOSE) Log.i(TAG, ".ts segment written: " + path);
				uploadService.submit(new Runnable(){

					@Override
					public void run() {
						File orig = new File(path);
						String url = s3Client.upload(getUUID() + File.separator + orig.getName(), orig, segmentUploadedCallback);
						if (VERBOSE) Log.i(TAG, ".ts segment destination url received: " + url);
					}
				});
			}

			@Override
			public void onManifestUpdated(String path) {
				if (VERBOSE) Log.i(TAG, ".m3u8 written: " + path);
				// Copy m3u8 at this moment and queue it to uploading service
				final File orig = new File(path);
				final File copy = new File(temp, orig.getName().replace(".m3u8", "_" + lastSegmentWritten + ".m3u8"));
				
				if (TRACE) Trace.beginSection("copyM3u8");
				try {
					FileUtils.copy(orig, copy);
				} catch (IOException e) {
					e.printStackTrace();
				}
				if (TRACE) Trace.endSection();
				uploadService.submit(new Runnable(){

					@Override
					public void run() {
						String url = s3Client.upload(getUUID() + File.separator + orig.getName(), copy, manifestUploadedCallback);
						// TODO: Delete copy
						if (VERBOSE) Log.i(TAG, ".m3u8 destination url received: " + url);
						
						if(!sentIsLiveBroadcast){
							broadcastRecordingIsLive(url);
							sentIsLiveBroadcast = true;
						}
					}
				});
			}
        	
        });
        observer.startWatching();
        Log.i(TAG, "Watching " + getOutputDirectory() + " for changes");
	}
	
	S3Callback segmentUploadedCallback = new S3Callback(){

		@Override
		public void onProgress(ProgressEvent progressEvent, long bytesUploaded,
				int percentUploaded) {
			if (VERBOSE) Log.i(TAG, String.format(".ts segment upload progress: %d event: %d", percentUploaded, progressEvent.getEventCode()));
			if(progressEvent.getEventCode() == ProgressEvent.COMPLETED_EVENT_CODE){
				if (VERBOSE) Log.i(TAG, ".ts segment upload success");
			} else if(progressEvent.getEventCode() == ProgressEvent.FAILED_EVENT_CODE){
				if (VERBOSE) Log.i(TAG, ".ts segment upload failed");
			}
		}
		
	};
	
	S3Callback manifestUploadedCallback = new S3Callback(){

		@Override
		public void onProgress(ProgressEvent progressEvent, long bytesUploaded,
				int percentUploaded) {
			if (VERBOSE) Log.i(TAG, String.format(".m3u8 upload progress: %d event: %d", percentUploaded, progressEvent.getEventCode()));
			if(progressEvent.getEventCode() == ProgressEvent.COMPLETED_EVENT_CODE){
				if (VERBOSE) Log.i(TAG, ".m3u8 upload success");
			} else if(progressEvent.getEventCode() == ProgressEvent.FAILED_EVENT_CODE){
				if (VERBOSE) Log.i(TAG, ".m3u8 upload failed");
			}
		}
		
	};
	
	/**
	 * Broadcasts a message to the LocalBroadcastManager
	 * indicating the HLS stream is live.
	 * This message is receivable only within the 
	 * hosting application
	 * @param url address of the HLS stream
	 */
	private void broadcastRecordingIsLive(String url) {
		  Log.d(TAG, String.format("Broadcasting Live HLS link: %s", url));
		  Intent intent = new Intent(INTENT_ACTION);
		  intent.putExtra("url", url);
		  intent.putExtra("status", HLS_STATUS.LIVE);
		  LocalBroadcastManager.getInstance(c).sendBroadcast(intent);
	}
}
