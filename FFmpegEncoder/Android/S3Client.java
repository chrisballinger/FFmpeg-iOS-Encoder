package com.example.ffmpegtest;

import java.io.File;

import android.content.Context;
import android.util.Log;

import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.services.s3.AmazonS3Client;
import com.amazonaws.services.s3.model.ProgressEvent;
import com.readystatesoftware.simpl3r.Uploader;
import com.readystatesoftware.simpl3r.Uploader.UploadProgressListener;

public class S3Client {
	private static final String TAG = "S3Client";
	
	AmazonS3Client s3;
	Context c;
	
	String bucket;
	
	public interface S3Callback{
		public void onProgress(ProgressEvent progressEvent, long bytesUploaded, int percentUploaded);
	}
	
	public S3Client(Context c, String AWS_KEY, String AWS_SECRET){
		s3 = new AmazonS3Client(new BasicAWSCredentials(SECRETS.AWS_KEY, SECRETS.AWS_SECRET));
		this.c = c;
	}
	
	/**
	 * Set the target S3 bucket of this client. 
	 * Must be set before calling upload.
	 * @param bucket The name of the target S3 bucket.
	 */
	public void setBucket(String bucket){
		this.bucket = bucket;
	}
	
	/**
	 * Begin an upload to S3. Returns the url to the completed upload.
	 * @param key Path relative to provided S3 bucket.
	 * @param source File reference to be uploaded.
	 * @param callback Callback providing upload progress.
	 * @return
	 */
	public String upload(String key, File source, final S3Callback callback){
		if(bucket == null){
			Log.e(TAG, "Bucket not set! Call setBucket(String bucket)");
			return "";
		}
		Uploader uploader = new Uploader(c, s3, bucket, key, source);
		uploader.setProgressListener(new UploadProgressListener() {         
		    @Override
		    public void progressChanged(ProgressEvent progressEvent, 
		            long bytesUploaded, int percentUploaded) {
		    	if(callback != null)
		    		callback.onProgress(progressEvent, bytesUploaded, percentUploaded);
		    }
		});
		return uploader.start();		
	}


}
