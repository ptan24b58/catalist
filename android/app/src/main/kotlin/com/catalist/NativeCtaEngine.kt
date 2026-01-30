package com.catalist

import java.util.Calendar

/**
 * Native Kotlin CTA engine — mirrors Dart's CTAEngine + CTAMessages.
 * Generates context-aware call-to-action messages using the same priority flow
 * and 30-min rotation as the Dart side.
 */
object NativeCtaEngine {

    enum class CTAContext {
        EMPTY,
        END_OF_DAY,
        DAILY_COMPLETED_ONE_5MIN,
        DAILY_ALL_COMPLETE,
        DAILY_IN_PROGRESS,
        LONG_TERM_COMPLETED_5MIN,
        LONG_TERM_IN_PROGRESS,
    }

    /** Generate CTA for given context. Rotates by 30-min block (matches Dart). */
    fun generate(context: CTAContext, hour: Int, minute: Int, progressLabel: String? = null): String {
        val list = messagesFor(context, hour)
        if (list.isEmpty()) return "Vivian, let's go"
        val seed = hour
        val i = seed % list.size
        val msg = list[i]
        if (context == CTAContext.DAILY_IN_PROGRESS && progressLabel != null) {
            if (i % 5 == 0) {
                val pre = PROGRESS_LABEL_PREFIXES[seed % PROGRESS_LABEL_PREFIXES.size]
                val suf = PROGRESS_LABEL_SUFFIXES[seed % PROGRESS_LABEL_SUFFIXES.size]
                return "$pre $progressLabel $suf"
            }
        }
        return msg
    }

    private fun messagesFor(context: CTAContext, hour: Int): List<String> {
        return when (context) {
            CTAContext.EMPTY -> emptyByHour(hour)
            CTAContext.END_OF_DAY -> END_OF_DAY
            CTAContext.DAILY_COMPLETED_ONE_5MIN -> COMPLETED_DAILY
            CTAContext.DAILY_ALL_COMPLETE -> ALL_DAILY_COMPLETE
            CTAContext.DAILY_IN_PROGRESS -> DAILY_URGENCY
            CTAContext.LONG_TERM_COMPLETED_5MIN -> COMPLETED_LONG_TERM
            CTAContext.LONG_TERM_IN_PROGRESS -> LONG_TERM_URGENCY
        }
    }

    private fun emptyByHour(hour: Int): List<String> {
        return when {
            hour in 5..10 -> EMPTY_MORNING
            hour in 11..16 -> EMPTY_AFTERNOON
            hour in 17..21 -> EMPTY_EVENING
            else -> EMPTY_NIGHT
        }
    }

    // ─── Empty messages (by time) ───

    private val EMPTY_MORNING = listOf(
        "Vivian. the list is empty. fix that?",
        "Add something. I'm bored.",
        "Vivian wake up and add a goal already",
        "Empty list club — you're the only member and it's not a flex",
        "Plot twist: add a goal and make today useful",
        "Morning Vivian. still nothing. shocking.",
        "The widget is empty and so is my will to live (add a goal pls)",
        "Vivian it's morning. the list is blank. connect the dots.",
        "Zero goals. zero fucks given. wait that's not right—",
        "Add one thing. just one. I'm begging.",
        "Empty widget hours. who's gonna break the streak? (hint: you)",
        "Vivian the app is judging you and honestly? same.",
    )
    private val EMPTY_AFTERNOON = listOf(
        "Vivian it's literally the afternoon and we have nothing",
        "Still zero goals. still judging (jk add one)",
        "The day is wasting and so is this widget",
        "Vivian. one goal. that's all I'm asking.",
        "Empty. void. nothing. ...you could change that",
        "Add a goal or I'll assume you're too cool for productivity (you're not)",
        "Afternoon check: still empty. still disappointed.",
        "Vivian it's past noon and this widget is still blank. the audacity.",
        "The afternoon is here and so is the emptiness. add something??",
        "Zero goals at 2pm. we love to see it (we don't)",
        "Vivian. afternoon. goals. now. please.",
        "Still nothing. still waiting. still judging silently.",
        "The widget is empty and honestly? mood. but also add a goal.",
        "Afternoon Vivian. the list says hi. it's lonely.",
        "Add one goal. just one. I'll stop bothering you (I won't)",
        "It's afternoon and we're still at zero. make it make sense.",
    )
    private val EMPTY_EVENING = listOf(
        "Last chance to pretend you had a productive day — add something",
        "Evening Vivian. the list is still judging you.",
        "Sun's going down. goals are still at zero. your move.",
        "Add one goal so we can say you tried",
        "Vivian it's evening and this is still empty I'm—",
        "One goal before bed. do it for the plot.",
        "Evening check-in: still empty. still not surprised.",
        "Vivian it's evening. the widget is blank. the vibes are off.",
        "Sunset. zero goals. add one for the aesthetic.",
        "Evening Vivian. add something. anything. I'm desperate.",
        "The day is ending and so is my patience. add a goal.",
        "One goal. evening. now. before I lose it.",
        "Vivian it's getting dark and so is my mood. add something pls.",
        "Evening hours. empty widget. add one goal for the serotonin.",
        "Last call for goals. add one or face the consequences (disappointment)",
        "Evening Vivian. the list is empty. fix it. now.",
    )
    private val EMPTY_NIGHT = listOf(
        "Set one for tmrw so future Vivian thanks you (or hates you less)",
        "It's late. add a goal for tmrw and go to bed",
        "Vivian. sleep soon. but like. add tmrw's goal first??",
        "Goals for tmrw >> scrolling till 2am (this is an intervention)",
        "Leave something for tomorrow-you. she'll need it.",
        "Night Vivian. add tmrw's goal. then sleep. in that order.",
        "It's late. the widget is empty. add one for tmrw. please.",
        "Vivian it's night. add a goal for tmrw before you pass out.",
        "Set one goal for tmrw. do it for future you. she deserves it.",
        "Night check: still empty. add tmrw's goal. go to bed. repeat.",
        "Vivian. late night. empty widget. add tmrw's goal. sleep. simple.",
        "One goal for tmrw. then bed. that's the deal.",
        "Night Vivian. the list is blank. add something for tmrw. now.",
        "Set a goal for tmrw. future Vivian will thank you (probably)",
        "It's late. add tmrw's goal. sleep. we'll talk in the morning.",
    )

    // ─── End of day (11pm+) ───

    private val END_OF_DAY = listOf(
        "Vivian. bed. now.",
        "It's 11. you know what that means. SLEEP.",
        "Go to bed before I start worrying about you",
        "Log off. close the eyes. goodnight Vivian.",
        "The only goal rn is getting under the blanket",
        "Stop. put the phone down. sleep. we'll be here tmrw.",
        "Vivian it's late. go to bed. I'm not asking.",
        "11pm Vivian. that's your cue. BED.",
        "Vivian. sleep. now. I'm serious this time.",
        "It's past 11. go to bed. Good night!",
        "Bed time Vivian. no arguments. just sleep.",
        "11pm check: are you in bed? no? fix that.",
        "Vivian it's late. close the phone. close your eyes. sleep.",
        "The only productive thing rn is going to bed. do that.",
        "Vivian. bed. blanket. sleep. that's the whole list.",
        "It's 11. you know what to do. (hint: it's not scrolling)",
        "Go to bed Vivian. I'll still be here tmrw. promise.",
        "11pm = bed time. no exceptions. Vivian. sleep.",
    )

    // ─── Daily completed (5 min) ───

    private val COMPLETED_DAILY = listOf(
        "VIVIAN. YOU DID IT. I'm so proud I could cry (I won't)",
        "One down!! who's gonna carry the boats. you. that's who.",
        "Look at you actually doing the thing. never thought I'd see the day",
        "You really did that. I'm shook. in a good way.",
        "Vivian that's a whole W right there. take the win.",
        "Completed. done. finished. we love to see it.",
        "Vivian you actually did it. I'm emotional. who are you.",
        "ONE DOWN. VIVIAN. ONE. DOWN. celebrate.",
        "You did the thing. the actual thing. I'm impressed.",
        "Vivian that's a dub. take it. own it. you earned it.",
        "Completed. finished. done. look at you go.",
        "Vivian you really did that. I'm not crying you're crying.",
        "You did it. you actually did it. I'm so proud.",
        "Vivian. W. that's it. that's the message.",
        "Goal completed. Vivian is so cool. we love to see it.",
        "You finished it. you really finished it. legend behavior.",
        "Vivian that's a whole accomplishment right there. take the W.",
    )

    // ─── All daily complete ───

    private val ALL_DAILY_COMPLETE = listOf(
        "Vivian you cleared the whole day. who are you.",
        "All of them goals? ALL. I'm impressed and a little scared",
        "Nothing left to do today. go rot in bed or whatever you want",
        "Every. Single. One. Vivian you're unhinged (in the best way)",
        "Vivian you finished EVERYTHING. who gave you permission to be this productive.",
        "You cleared the whole list. the entire thing. I'm in awe.",
        "Vivian. all of them. ALL. I'm not okay. (in a good way)",
        "Every goal done. every single one. Vivian you're different.",
        "Nothing left. zero. nada. Vivian you're free. go live your life.",
        "You finished them all. the whole day. I'm emotional.",
        "Vivian you cleared the entire list. who are you and what did you do with the real Vivian.",
        "All goals done. Vivian cool. we love to see it.",
        "Every single one. finished. done. Vivian you're unhinged! great job!",
        "Vivian. all of them. ALL. I'm scared and impressed.",
        "The whole day. cleared. Vivian you're built different.",
    )

    // ─── Long-term completed (5 min) ───

    private val COMPLETED_LONG_TERM = listOf(
        "A LONG-TERM GOAL. VIVIAN. YOU FINISHED IT.",
        "That was supposed to take forever and you just— did it.",
        "Who finishes long-term goals. you apparently. legend.",
        "Vivian. VIV. that's not a small thing. that's huge.",
        "I was not emotionally prepared for you to actually finish that",
        "Vivian you finished a LONG-TERM GOAL. I'm not okay. (in the best way)",
        "That big goal? FINISHED. Vivian you're different.",
        "You actually finished it. the whole thing. I'm shook.",
        "Vivian that was supposed to take months and you just— did it.",
        "A long-term goal. finished. Vivian you're unhinged! great job!",
        "Vivian. VIVIAN. that's huge. that's massive. that's everything.",
        "You finished a long-term goal. I'm emotional. who are you.",
        "That goal that was supposed to take forever? DONE. Vivian so cool!",
        "Vivian you really did that. the whole thing. I'm so proud.",
        "A long-term goal. completed. Vivian you're built different.",
        "Vivian. that's not small. that's not medium. that's HUGE.",
        "You finished it. the long-term one. I'm not crying you're crying.",
        "Vivian you completed a long-term goal. who gave you permission to be this amazing.",
    )

    // ─── Daily in progress (urgency) ───

    private val DAILY_URGENCY = listOf(
        "Vivian you started it. now finish it. I believe in you (barely)",
        "Update the progress or I'll assume you gave up (did you?)",
        "That goal's still there. staring. waiting. judgey.",
        "Log something. anything. show the app you're alive",
        "You're so close and yet so far. go fix that.",
        "Still in progress. still waiting. you know what to do.",
        "Vivian. one step. then another. you got this (I mean it this time)",
        "That goal's not gonna finish itself. just saying.",
        "Vivian you're in progress. finish it. I'm waiting.",
        "Update the progress. do it. now. please.",
        "That goal's still there. still waiting. still judgey.",
        "Log something Vivian. anything. show me you're trying.",
        "You started it. finish it. that's the whole thing.",
        "Vivian. progress. update. now. I believe in you (maybe)",
        "That goal's not done yet. fix that. please.",
        "Still in progress. still waiting. Vivian you know what to do.",
        "Update it. log it. finish it. Vivian. please.",
        "You're so close. so so close. finish it.",
        "Vivian that goal's still there. staring. finish it.",
        "Progress check: still in progress. finish it. now.",
        "Vivian you started it. now finish it. I'm rooting for you (barely)",
        "That goal's waiting. you're waiting. someone make a move.",
    )

    // ─── Long-term in progress ───

    private val LONG_TERM_URGENCY = listOf(
        "That big goal still exists. just a reminder. love that for you",
        "Vivian when's the last time you touched the long-term one. be honest.",
        "Quick check-in: have you forgotten about your future self?",
        "Log a little progress. future Vivian will not hate you as much",
        "The long-term goal says hi. and it's disappointed.",
        "You opened this app. might as well nudge that big goal a tiny bit.",
        "That long-term goal? still there. still waiting. still judgey.",
        "Vivian the big goal exists. remember? touch it. please.",
        "Long-term goal check: still exists. still waiting. still disappointed.",
        "Vivian when did you last update the big one. be honest. I'll wait.",
        "That big goal's still there. just a friendly reminder.",
        "Quick check: have you touched the long-term goal? no? fix that.",
        "The long-term goal says hi. it misses you. (it's disappointed)",
        "Vivian you opened the app. update the big goal. do it.",
        "That long-term goal? still waiting. still there. still judgey.",
        "Future Vivian is waiting. update the big goal. please.",
        "The long-term one exists. remember? touch it. log something.",
        "Vivian the big goal's still there. still waiting. still disappointed.",
        "Long-term goal: exists. Vivian: ignoring it. fix that.",
        "That big goal? still there. still waiting. Vivian. please.",
        "Quick reminder: the long-term goal exists. touch it. now.",
        "Vivian you're here. the big goal's here. make them meet.",
    )

    // ─── Progress label snippets ───

    private val PROGRESS_LABEL_PREFIXES = listOf(
        "Vivian you're sitting at",
        "Look at you, at",
        "You've made it to",
        "Currently vibing at",
        "Progress check: you're at",
        "Vivian look — you're at",
        "The numbers say you're at",
        "You're chilling at",
    )
    private val PROGRESS_LABEL_SUFFIXES = listOf(
        "— don't leave it hanging",
        "— so close. finish it.",
        "— you didn't come this far to come this far",
        "— no backing out now",
        "— almost there. finish it.",
        "— you're so close. don't quit now.",
        "— Vivian you're almost done. finish it.",
        "— so close and yet so far. fix that.",
        "— almost there. almost. finish it.",
        "— you didn't come this far to stop now",
        "— Vivian you're close. finish it. please.",
        "— so close. so so close. finish it.",
        "— almost done. almost. finish it.",
        "— you're almost there. don't stop now.",
        "— Vivian finish it. you're so close.",
    )
}
