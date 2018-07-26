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
import android.widget.TextView;
import android.view.ViewGroup.LayoutParams;
import android.widget.RelativeLayout;
import android.support.v7.app.ActionBar;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.view.View.OnClickListener;
import android.view.Gravity;
import android.util.TypedValue;

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
                // getActionBar().setTitle(Html.fromHtml("<font color='#ffffff'>" + title + "</font>"));

                TextView tv = new TextView(getApplicationContext());
                
                LinearLayout.LayoutParams textLayoutParams = new LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
                tv.setGravity(Gravity.LEFT | Gravity.CENTER);
                tv.setLayoutParams(textLayoutParams);
                tv.setText(title);
                tv.setTextColor(Color.WHITE);
                textLayoutParams.setMargins(30, 0, 0, 0);
                tv.setTextSize(TypedValue.COMPLEX_UNIT_SP,20);

                LinearLayout layout = createlayout();

                LinearLayout.LayoutParams imgLayoutParams = new LinearLayout.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
                ImageView img = new ImageView(getApplicationContext());
                imgLayoutParams.gravity= Gravity.LEFT | Gravity.CENTER_VERTICAL;
                img.setLayoutParams(imgLayoutParams);
                img.setImageDrawable(changeBackArrowColor(getApplicationContext(), 243));
                img.setOnClickListener(clickListener);

                layout.addView(img);
                layout.addView(tv);

                getActionBar().setDisplayOptions(ActionBar.DISPLAY_SHOW_CUSTOM);
                getActionBar().setCustomView(layout);

                ColorDrawable cd = new ColorDrawable(0xFF13273B);
                getActionBar().setBackgroundDrawable(cd);
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            Window window = getWindow();
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
            getWindow().setStatusBarColor(Color.parseColor("#FF13273B"));
        }      
    }
    
    OnClickListener clickListener = new OnClickListener() {
        public void onClick(View v) {
            finish();
        }
    };

    private LinearLayout createlayout(){
        LinearLayout layout = new LinearLayout(getApplicationContext());
        layout.setOrientation(LinearLayout.HORIZONTAL);
        layout.setLayoutParams(new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT));
        return layout;
    }

    private Drawable changeBackArrowColor(Context context, int color) {
        String resName = Build.VERSION.SDK_INT >= 23 ? "abc_ic_ab_back_material" : "abc_ic_ab_back_mtrl_am_alpha";
        int res = context.getResources().getIdentifier(resName, "drawable", context.getPackageName());;
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
