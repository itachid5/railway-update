FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV COLORTERM=truecolor

# প্রয়োজনীয় প্যাকেজ এবং procps (ps কমান্ডের জন্য) ইন্সটল করা হচ্ছে
RUN apt-get update && apt-get install -y \
    openssh-server sudo curl wget git nano procps \
    && rm -rf /var/lib/apt/lists/*

# SSH ফোল্ডার তৈরি এবং ইউজার/পাসওয়ার্ড সেটআপ
RUN mkdir -p /var/run/sshd && \
    useradd -m -s /bin/bash -u 1000 devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "devuser:123456" | chpasswd && \
    echo "root:123456" | chpasswd && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# 1. প্রম্পট (PS1) কে বোল্ড এবং রঙিন করা হচ্ছে
RUN echo "export PS1='\[\e[1;32m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\$ '" >> /home/devuser/.bashrc && \
    echo "export PS1='\[\e[1;31m\]\u@phoenix\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]# '" >> /root/.bashrc

# 2. আপনার দেওয়া 'mm' ফাংশনটি একটি টেম্পোরারি ফাইলে লিখে উভয়ের .bashrc তে যোগ করা হচ্ছে
RUN cat > /tmp/mm.sh <<'EOF'
function mm() {
    # Color Codes
    C_C="\e[36m"     # Cyan
    C_G="\e[90m"     # Gray
    C_W="\e[1;37m"   # Bold White
    C_R="\e[0m"      # Reset

    echo -e "\n${C_W}▶ SYSTEM MONITOR${C_R}"
    echo -e "${C_G}------------------------------------------------------------${C_R}"
    
    # Helper function for perfect column alignment
    print_row() {
        local icon="$1"
        # Pad strings with spaces to ensure perfect vertical alignment
        local name=$(printf "%-5s" "$2")
        local col1=$(printf "%-11s" "$3")
        local col2=$(printf "%-11s" "$4")
        local col3=$(printf "%-12s" "$5")
        
        # Using the clean unicode icons
        echo -e " ${icon}   ${C_W}${name}${C_R} ${C_G}::${C_R}  ${C_C}${col1}${C_R} ${C_G}|${C_R}  ${C_C}${col2}${C_R} ${C_G}|${C_R}  ${C_C}${col3}${C_R}"
    }

    # 1. RAM Calculation
    RAM_MAX=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)
    RAM_USED_KB=$(ps -U $USER -o rss | awk 'NR>1 {sum+=$1} END {if(sum=="") sum=0; print sum}')
    RAM_USED_MB=$((RAM_USED_KB / 1024))
    if [[ "$RAM_MAX" =~ ^[0-9]+$ ]]; then
        RAM_MAX_MB=$((RAM_MAX / 1024 / 1024))
        RAM_FREE_MB=$((RAM_MAX_MB - RAM_USED_MB))
        R1="${RAM_MAX_MB}MB Max"
        R2="${RAM_USED_MB}MB Used"
        R3="${RAM_FREE_MB}MB Free"
    else
        R1="Unlimited"
        R2="${RAM_USED_MB}MB Used"
        R3="---"
    fi

    # 2. CPU Calculation
    CPU_USED=$(ps -U $USER -o %cpu | awk 'NR>1 {sum+=$1} END {if(sum=="") sum=0; print sum}')
    CPU_FREE=$(awk -v used="$CPU_USED" 'BEGIN {print 200 - used}')
    C1="200% Max"
    C2="${CPU_USED}% Used"
    C3="${CPU_FREE}% Free"

    # 3. Storage Calculation
    D_MAX=$(df -h / | awk 'NR==2 {print $2}')
    D_USED=$(df -h / | awk 'NR==2 {print $3}')
    D_FREE=$(df -h / | awk 'NR==2 {print $4}')
    D1="${D_MAX} Max"
    D2="${D_USED} Used"
    D3="${D_FREE} Free"
    
    # 4. File Usage Calculation
    HOME_USAGE=$(du -sh ~ 2>/dev/null | awk '{print $1}')
    F1="---"
    F2="${HOME_USAGE} Used"
    F3="/home/$USER"
    
    # Render UI with your requested icons
    print_row "❖" "RAM" "$R1" "$R2" "$R3"
    print_row "⚙" "CPU" "$C1" "$C2" "$C3"
    print_row "⛁" "DISK" "$D1" "$D2" "$D3"
    print_row "▣" "FILES" "$F1" "$F2" "$F3"
    
    echo -e "${C_G}------------------------------------------------------------${C_R}\n"
}

# শুধুমাত্র SSH দিয়ে লগইন করার সময় ফাংশনটি নিজে থেকে রান হবে
if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    mm
fi
EOF

# টেম্পোরারি ফাইলটি মূল ফাইলে যুক্ত করে ডিলিট করা হচ্ছে
RUN cat /tmp/mm.sh >> /home/devuser/.bashrc && \
    cat /tmp/mm.sh >> /root/.bashrc && \
    rm /tmp/mm.sh

# start.sh স্ক্রিপ্ট সরাসরি Dockerfile-এর ভেতরেই তৈরি করা হচ্ছে
RUN cat > /start.sh <<'SH'
#!/bin/bash
set -e

# SSH সার্ভার চালু করা হচ্ছে
/usr/sbin/sshd

# কন্টেইনারটি সচল রাখার জন্য
tail -f /dev/null
SH

# স্ক্রিপ্টটিকে এক্সিকিউটেবল করা হচ্ছে
RUN sed -i 's/\r$//' /start.sh && chmod +x /start.sh

WORKDIR /root

EXPOSE 22

CMD ["/start.sh"]
