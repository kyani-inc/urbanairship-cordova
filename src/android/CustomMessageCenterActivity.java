/* Copyright 2018 Urban Airship and Contributors */

package com.urbanairship.cordova;

import android.content.Intent;
import android.os.Bundle;

import android.text.Html;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.ColorDrawable;
import android.graphics.Color;
import android.view.View;
import android.graphics.PorterDuff.Mode;
import android.graphics.PorterDuff;
import android.os.Build;
import android.content.Context;
import android.view.WindowManager;
import android.view.Window;

import com.urbanairship.messagecenter.MessageCenterActivity;
import com.urbanairship.messagecenter.MessageCenterFragment;
import com.urbanairship.richpush.RichPushInbox;

public class CustomMessageCenterActivity extends MessageCenterActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        String title;

        if (getIntent() != null && "CLOSE".equals(getIntent().getAction())) {
            finish();
            return;
        }

        if (getIntent() != null && getIntent().getData() != null && RichPushInbox.VIEW_INBOX_INTENT_ACTION.equals(getIntent().getAction())) {
            String messageId = getIntent().getData().getSchemeSpecificPart();
            getSupportFragmentManager().executePendingTransactions();
            MessageCenterFragment fragment = (MessageCenterFragment) getSupportFragmentManager().findFragmentByTag("MESSAGE_CENTER_FRAGMENT");
            fragment.setMessageID(messageId);
        }

        Intent intent = getIntent();
        Bundle bundle = intent.getExtras();

        if(bundle!=null)
        {
            title =(String)bundle.get("TITLE");
            if(title != null && !title.isEmpty()){
                getActionBar().setTitle(Html.fromHtml("<font color='#ffffff'>" + title + "</font>"));
                ColorDrawable cd = new ColorDrawable(0xFF13273B);
                getActionBar().setBackgroundDrawable(cd);
                changeBackArrowColor(getApplicationContext(), 243);
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            Window window = getWindow();
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
            getWindow().setStatusBarColor(Color.parseColor("#FF13273B"));
        }      
    }

    private Drawable changeBackArrowColor(Context context, int color) {
        String resName;
        int res;

        resName = Build.VERSION.SDK_INT >= 23 ? "abc_ic_ab_back_material" : "abc_ic_ab_back_mtrl_am_alpha";
        res = context.getResources().getIdentifier(resName, "drawable", context.getPackageName());

        final Drawable upArrow = context.getResources().getDrawable(res);
        upArrow.setColorFilter(color, PorterDuff.Mode.SRC_ATOP);
        getActionBar().setHomeAsUpIndicator(upArrow);
        return upArrow;
    }    

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);

        if (intent != null && "CLOSE".equals(intent.getAction())) {
            finish();
            return;
        }

        if (intent != null && intent.getData() != null && intent.getAction() != null) {
            String s = intent.getAction();
            if (s.equals(RichPushInbox.VIEW_MESSAGE_INTENT_ACTION) || s.equals(RichPushInbox.VIEW_INBOX_INTENT_ACTION)) {
                String messageId = getIntent().getData().getSchemeSpecificPart();
                MessageCenterFragment fragment = (MessageCenterFragment) getSupportFragmentManager().findFragmentByTag("MESSAGE_CENTER_FRAGMENT");
                fragment.setMessageID(messageId);

            }
        }
    }
}
