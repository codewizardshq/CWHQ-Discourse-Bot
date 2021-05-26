# name: CWHQ-Discourse-Bot
# about: This plugin adds extra functionality to the @system user on a Discourse forum.
# version: 1.9.0
# authors: Qursch, bronze0202, linuxmasters, sep208
# url: https://github.com/codewizardshq/CWHQ-Discourse-Bot

require 'date'

courses = Hash.new
courses = {
    36 => "e13_real_prog_00",
    37 => "e14_minecraft_00",
    45 => "e21_prog_concepts_00",
    31 => "e22_wd1_00",
    58 => "e23",
    46 => "e24",
    13 => "intro_prog_py_00",
    14 => "m12_html_css_00",
    15 => "m13_js_00",
    16 => "M14_vr_00",
    17 => "m21_ui_00",
    18 => "m22_database_00",
    47 => "m23_api_00",
    48 => "m24_omg_00",
    53 => "m31_flask_00",
    54 => "m32",
    55 => "m33",
    56 => "m34",
    20 => "h11_intro_python_00",
    21 => "h12_web_dev_00",
    22 => "h13_ui_00",
    23 => "h14_api_00",
    49 => "h21_framework_00",
    50 => "h22_mvc_00",
    51 => "h23",
    52 => "h24",
    59 => "h31",
    60 => "h32",
    61 => "h33",
    62 => "h34",
    11 => false,
    57 => false
}

def get_link(id, username, hash)
    if id == 11 || id == 57 then
        return "`https://scratch.mit.edu/projects/00000000`" 
    else
        if !hash[id].nil? then
            return "`https://" + username + ".codewizardshq.com/" + hash[id] + "/project`"
        end
    end
    return false
end

def create_post(topicId, text)
    post = PostCreator.create(
        Discourse.system_user,
        skip_validations: true,
        topic_id: topicId,
        raw: text)
    unless post.nil?
        post.save(validate: false)
    end
end

def closeTopic(id, message)
    topic = Topic.find_by(id: id)               
    topic.update_status("closed", true, Discourse.system_user, {message: message})
end

def check_title(title)
    if title.downcase.include?("codewizardshq.com") || title.downcase.include?("scratch.mit.edu") then
        return true
    else
        return false
    end
end

def check_all_link_types(text)
    if (text.include?("codewizardshq.com") && !text.include?("/edit")) || (text.include?("cwhq-apps") || text.include?("scratch.mit.edu")) then
        return true
    end
end

def send_pm(title, text, user)
    message = PostCreator.create!(
        Discourse.system_user,
        title: title,
        raw: text,
        archetype: Archetype.private_message,
        target_usernames: user,
        skip_validations: true
    )
end
def log_command(user, command, text, link)
    text = "@" + user + command + "<br>" + "`#{text}" + "<br>" + link
    log_topic = 1
    create_post(SiteSetting.log_topic_id, text)
end
after_initialize do
   

    DiscourseEvent.on(:topic_created) do |topic| 
        newTopic = Post.find_by(topic_id: topic.id, post_number: 1)
        topicRaw = newTopic.raw
        lookFor = topic.user.username + ".codewizardshq.com"
        link = get_link(topic.category_id, topic.user.username, courses)
        if link then
            if topicRaw.downcase.include?(lookFor + "/edit") then
                text = "Hello @" + topic.user.username + ", it appears that the link that you provided goes to the editor, and not your project. Please open your project and use the link from that tab. This may look like " + link + "."
                create_post(topic.id, text)
            elsif !topicRaw.downcase.include?(lookFor) && !topicRaw.downcase.include?("cwhq-apps.com") then
                text = "Hello @" + topic.user.username + ", it appears that you did not provide a link to your project. In order to recieve the best help, please edit your topic to contain a link to your project. This may look like " + link + "."
                create_post(topic.id, text)
            end

        end

        topic_title = topic.title
        
        if check_title(topic_title) then
            text = "Hello @" + topic.user.username + ", it appears you provided a link in your topic's title. Please change the title of this topic to something that clearly explains what the topic is about. This will help other forum users know what you want to show or get help with. You can edit your topic title by pressing the pencil icon next to the current one. Be sure to put the link in the main body of your post."
            if topicRaw.downcase.include?(lookFor) || topicRaw.downcase.include?("scratch.mit.edu") then
                create_post(topic.id, text)
            else
                create_post(topic.id, text)
            end
        end
    end


# command check
    DiscourseEvent.on(:post_created) do |post|
        if post.post_number != 1 && post.user_id != -1 then
            raw = post.raw
            oPost = Post.find_by(topic_id: post.topic_id, post_number: 1)
            group = Group.find_by(id: post.user.primary_group_id)
            helpLinks = "
            [Forum Videos](https://forum.codewizardshq.com/t/informational-videos/8662)
            [Rules Of The Forum](https://forum.codewizardshq.com/t/rules-of-the-codewizardshq-community-forum/43)
            [Create Good Questions And Answers](https://forum.codewizardshq.com/t/create-good-questions-and-answers/69)
            [Forum Guide](https://forum.codewizardshq.com/t/forum-new-user-guide/47)
            [Meet Forum Helpers](https://forum.codewizardshq.com/t/meet-the-forum-helpers/5474)
            [System Documentation](https://forum.codewizardshq.com/t/system-add-on-plugin-documentation/8742)
            [Understanding Trust Levels](https://blog.discourse.org/2018/06/understanding-discourse-trust-levels/)
            [Forum Information Category](https://forum.codewizardshq.com/c/official/information/69)"
            command = 0
            user = post.user.username
            link = "https://forum.codewizardshq.com/t/#{post.topic_slug}/#{post.topic_id}"
            if raw[0, 7].downcase == "@system" then

                if raw[8, 5] == "close" then
                    if (!post.user.primary_group_id.nil? && group.name == "Helpers") || (oPost.user.username == post.user.username && !courses[post.topic.category_id].nil?) then
                        text = "Closed by @" + post.user.username + ": " + raw[14..raw.length]
                        if oPost.user.username == post.user.username then
                            text = "Closed by topic creator: " + raw[14..raw.length]
                        end
                        closeTopic(post.topic_id, text)
                        PostDestroyer.new(Discourse.system_user, post).destroy
                        command = `closed topic: "#{post.topic_slug}"(#{post.topic_id})`
                    end


                elsif raw[8, 6] == "remove" then
                    if (!post.user.primary_group_id.nil? && group.name == "Helpers") then
                        first_reply = Post.find_by(topic_id: post.topic_id, post_number: 2)
                        second_reply = Post.find_by(topic_id: post.topic_id, post_number: 3)
                        if !first_reply.nil? && first_reply.user.username == "system" then
                            PostDestroyer.new(Discourse.system_user, first_reply).destroy
                        end
                        if !second_reply.nil? && second_reply.user.username == "system" then
                            PostDestroyer.new(Discourse.system_user, second_reply).destroy
                        end
                        PostDestroyer.new(Discourse.system_user, post).destroy
                        command = "removed system message(s)"
                      end

                      
                elsif raw[8, 4] == "help" && raw[13] != "@" then
                  text = "Hello @" + post.user.username + ". Here are some resources to help you on the forum:" + helpLinks
                  command = "sent public help"
                  create_post(post.topic_id, text)


                elsif raw[8,4] == "help" && raw[13] == "@" then
                    if post.user.trust_level >= TrustLevel[3] then
                        for i in 1..raw.length
                            if !User.find_by(username: raw[14, (1+i)]).nil? then
                                helpUser = User.find_by(username: raw[14, (1+i)])
                                helper = post.user
                                title = "Help with the CodeWizardsHQ Forum"
                                raw = "Hello @" + helpUser.username + ", @" + helper.username + " thinks you might need some help gettting around the forum. Here are some resources that you can read if you would like to know more about this forum:" + helpLinks +  "<br> <br>This message was sent using the [@system help command](https://forum.codewizardshq.com/t/system-add-on-plugin-documentation/8742)." 
                                command = "sent private help to @#{helpuser.username}"
                                send_pm(title, raw, helpUser.username)
                                PostDestroyer.new(Discourse.system_user, post).destroy
                                break
                            end
                        end
                    end

                end
            elsif post.user.username == oPost.user.username && !courses[post.topic.category_id].nil? then
                phrases = ["homework help", "on my own", "thanks", "thank you", "figured it out", "it works", "it's working", "myself", "solved", "fixed"]
                phrases.each do |i|
                    if raw.downcase.include?(i) then
                        text = "Hello @#{post.user.username}. Based on your last reply, it seems like the issue you needed help with has been solved. If you would like to close the topic, meaning there will be no more replies allowed, follow the instructions below. If your problem is not solved or you would like to leave the topic open, you may ignore this or submit feedback [here](https://forum.codewizardshq.com/t/bot-commands-and-pr-suggestions-for-system/9254).<br><br>To close your topic, navigate back to your topic (the easiest way to do this is to press the back button to take you the last page you were on). Then make a new reply, and in it type `@system close problem solved`. If you need to, you can replace `problem solved` with a diferent reason for closing. When you post your reply, the topic should close."
                        title = "Do you want to close your get help topic?"
                        command = "was sent a topic closing message"
                        send_pm(title, text, post.user.username)
                        break
                    end
                end
            end
            if command != 0 then
                log_command(user, command, raw, link)
            end
        end
    end


    DiscourseEvent.on(:post_edited) do |post|
        if post.post_number == 1 && check_all_link_types(post.raw) then
            first_reply = Post.find_by(topic_id: post.topic_id, post_number: 2)
            second_reply = Post.find_by(topic_id: post.topic_id, post_number: 3)
            if !first_reply.nil? && first_reply.user.username == "system" then
                PostDestroyer.new(Discourse.system_user, first_reply).destroy
            end
            if !second_reply.nil? && second_reply.user.username == "system" then
                PostDestroyer.new(Discourse.system_user, second_reply).destroy
            end
        end
    end
end
