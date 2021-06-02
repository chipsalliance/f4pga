struct ql_dsp_pm {
    Module *module;
    SigMap sigmap;
    std::function<void()> on_accept;
    bool setup_done;
    bool generate_mode;
    int accept_cnt;

    uint32_t rngseed;
    int rng(unsigned int n)
    {
        rngseed ^= rngseed << 13;
        rngseed ^= rngseed >> 17;
        rngseed ^= rngseed << 5;
        return rngseed % n;
    }

    typedef std::tuple<> index_0_key_type;
    typedef std::tuple<Cell *> index_0_value_type;
    dict<index_0_key_type, vector<index_0_value_type>> index_0;
    typedef std::tuple<SigBit> index_6_key_type;
    typedef std::tuple<Cell *, IdString> index_6_value_type;
    dict<index_6_key_type, vector<index_6_value_type>> index_6;
    typedef std::tuple<SigSpec> index_8_key_type;
    typedef std::tuple<Cell *, IdString> index_8_value_type;
    dict<index_8_key_type, vector<index_8_value_type>> index_8;
    typedef std::tuple<SigBit> index_16_key_type;
    typedef std::tuple<Cell *, int> index_16_value_type;
    dict<index_16_key_type, vector<index_16_value_type>> index_16;
    typedef std::tuple<SigBit> index_20_key_type;
    typedef std::tuple<Cell *, int> index_20_value_type;
    dict<index_20_key_type, vector<index_20_value_type>> index_20;
    dict<SigBit, pool<Cell *>> sigusers;
    pool<Cell *> blacklist_cells;
    pool<Cell *> autoremove_cells;
    dict<Cell *, int> rollback_cache;
    int rollback;

    struct state_ql_dsp_t {
        Cell *add;
        IdString addAB;
        SigSpec argD;
        SigSpec argQ;
        bool argSdff;
        bool cd_signed;
        SigBit clock;
        bool clock_pol;
        Cell *ff;
        Cell *ffA;
        Cell *ffB;
        Cell *ffCD;
        Cell *ffFJKG;
        Cell *ffH;
        Cell *ffO;
        Cell *mul;
        Cell *mux;
        IdString muxAB;
        bool o_lo;
        SigSpec sigA;
        SigSpec sigB;
        SigSpec sigCD;
        SigSpec sigH;
        SigSpec sigO;
    } st_ql_dsp;

    struct udata_ql_dsp_t {
        Cell *dff;
        SigSpec dffD;
        SigSpec dffQ;
        SigBit dffclock;
        bool dffclock_pol;
    } ud_ql_dsp;

    IdString id_b_A{"\\A"};
    IdString id_b_ARST{"\\ARST"};
    IdString id_b_ARST_POLARITY{"\\ARST_POLARITY"};
    IdString id_b_A_REG{"\\A_REG"};
    IdString id_b_A_SIGNED{"\\A_SIGNED"};
    IdString id_b_B{"\\B"};
    IdString id_b_B_REG{"\\B_REG"};
    IdString id_b_B_SIGNED{"\\B_SIGNED"};
    IdString id_b_CLK{"\\CLK"};
    IdString id_b_CLK_POLARITY{"\\CLK_POLARITY"};
    IdString id_b_C_REG{"\\C_REG"};
    IdString id_b_D{"\\D"};
    IdString id_b_D_REG{"\\D_REG"};
    IdString id_b_EN{"\\EN"};
    IdString id_b_O{"\\O"};
    IdString id_b_Q{"\\Q"};
    IdString id_b_QL_DSP{"\\QL_DSP"};
    IdString id_b_SRST{"\\SRST"};
    IdString id_b_SRST_VALUE{"\\SRST_VALUE"};
    IdString id_b_ENABLE_DSP{"\\ENABLE_DSP"};
    IdString id_b_Y{"\\Y"};
    IdString id_b_init{"\\init"};
    IdString id_b_keep{"\\keep"};
    IdString id_d_add{"$add"};
    IdString id_d_dff{"$dff"};
    IdString id_d_dffe{"$dffe"};
    IdString id_d_mul{"$mul"};
    IdString id_d_mux{"$mux"};
    IdString id_d_sdff{"$sdff"};
    IdString id_d_sdffce{"$sdffce"};

    void add_siguser(const SigSpec &sig, Cell *cell)
    {
        for (auto bit : sigmap(sig)) {
            if (bit.wire == nullptr)
                continue;
            sigusers[bit].insert(cell);
        }
    }

    void blacklist(Cell *cell)
    {
        if (cell != nullptr && blacklist_cells.insert(cell).second) {
            auto ptr = rollback_cache.find(cell);
            if (ptr == rollback_cache.end())
                return;
            int rb = ptr->second;
            if (rollback == 0 || rollback > rb)
                rollback = rb;
        }
    }

    void autoremove(Cell *cell)
    {
        if (cell != nullptr) {
            autoremove_cells.insert(cell);
            blacklist(cell);
        }
    }

    SigSpec port(Cell *cell, IdString portname) { return sigmap(cell->getPort(portname)); }

    SigSpec port(Cell *cell, IdString portname, const SigSpec &defval) { return sigmap(cell->connections_.at(portname, defval)); }

    Const param(Cell *cell, IdString paramname) { return cell->getParam(paramname); }

    Const param(Cell *cell, IdString paramname, const Const &defval) { return cell->parameters.at(paramname, defval); }

    int nusers(const SigSpec &sig)
    {
        pool<Cell *> users;
        for (auto bit : sigmap(sig))
            for (auto user : sigusers[bit])
                users.insert(user);
        return GetSize(users);
    }

    ql_dsp_pm(Module *module, const vector<Cell *> &cells)
        : module(module), sigmap(module), setup_done(false), generate_mode(false), rngseed(12345678)
    {
        setup(cells);
    }

    ql_dsp_pm(Module *module) : module(module), sigmap(module), setup_done(false), generate_mode(false), rngseed(12345678) {}

    void setup(const vector<Cell *> &cells)
    {
        ud_ql_dsp.dff = nullptr;
        ud_ql_dsp.dffD = SigSpec();
        ud_ql_dsp.dffQ = SigSpec();
        ud_ql_dsp.dffclock = SigBit();
        ud_ql_dsp.dffclock_pol = bool();
        log_assert(!setup_done);
        setup_done = true;
        for (auto port : module->ports)
            add_siguser(module->wire(port), nullptr);
        for (auto cell : module->cells())
            for (auto &conn : cell->connections())
                add_siguser(conn.second, cell);
        for (auto cell : cells) {
            do {
                Cell *mul = cell;
                index_0_value_type value;
                std::get<0>(value) = cell;
                if (!(mul->type.in(id_d_mul, id_b_QL_DSP)))
                    continue;
                if (!(GetSize(mul->getPort(id_b_A)) + GetSize(mul->getPort(id_b_B)) > 10))
                    continue;
                index_0_key_type key;
                index_0[key].push_back(value);
            } while (0);
            do {
                Cell *add = cell;
                index_6_value_type value;
                std::get<0>(value) = cell;
                if (!(add->type.in(id_d_add)))
                    continue;
                vector<IdString> _pmg_choices_AB = {id_b_A, id_b_B};
                for (const IdString &AB : _pmg_choices_AB) {
                    std::get<1>(value) = AB;
                    if (!(nusers(port(add, AB)) == 2))
                        continue;
                    index_6_key_type key;
                    std::get<0>(key) = port(add, AB)[0];
                    index_6[key].push_back(value);
                }
            } while (0);
            do {
                Cell *mux = cell;
                index_8_value_type value;
                std::get<0>(value) = cell;
                if (!(mux->type == id_d_mux))
                    continue;
                vector<IdString> _pmg_choices_AB = {id_b_A, id_b_B};
                for (const IdString &AB : _pmg_choices_AB) {
                    std::get<1>(value) = AB;
                    if (!(nusers(port(mux, AB)) == 2))
                        continue;
                    index_8_key_type key;
                    std::get<0>(key) = port(mux, AB);
                    index_8[key].push_back(value);
                }
            } while (0);
            do {
                Cell *ff = cell;
                index_16_value_type value;
                std::get<0>(value) = cell;
                if (!(ff->type.in(id_d_dff, id_d_dffe)))
                    continue;
                if (!(param(ff, id_b_CLK_POLARITY).as_bool()))
                    continue;
                int &offset = std::get<1>(value);
                for (offset = 0; offset < GetSize(port(ff, id_b_D)); offset++) {
                    index_16_key_type key;
                    std::get<0>(key) = port(ff, id_b_Q)[offset];
                    index_16[key].push_back(value);
                }
            } while (0);
            do {
                Cell *ff = cell;
                index_20_value_type value;
                std::get<0>(value) = cell;
                if (!(ff->type.in(id_d_dff, id_d_dffe, id_d_sdff, id_d_sdffce)))
                    continue;
                if (!(param(ff, id_b_CLK_POLARITY).as_bool()))
                    continue;
                int &offset = std::get<1>(value);
                for (offset = 0; offset < GetSize(port(ff, id_b_D)); offset++) {
                    index_20_key_type key;
                    std::get<0>(key) = port(ff, id_b_D)[offset];
                    index_20[key].push_back(value);
                }
            } while (0);
        }
    }

    ~ql_dsp_pm()
    {
        for (auto cell : autoremove_cells)
            module->remove(cell);
    }

    int run_ql_dsp(std::function<void()> on_accept_f)
    {
        log_assert(setup_done);
        accept_cnt = 0;
        on_accept = on_accept_f;
        rollback = 0;
        st_ql_dsp.add = nullptr;
        st_ql_dsp.addAB = IdString();
        st_ql_dsp.argD = SigSpec();
        st_ql_dsp.argQ = SigSpec();
        st_ql_dsp.argSdff = bool();
        st_ql_dsp.cd_signed = bool();
        st_ql_dsp.clock = SigBit();
        st_ql_dsp.clock_pol = bool();
        st_ql_dsp.ff = nullptr;
        st_ql_dsp.ffA = nullptr;
        st_ql_dsp.ffB = nullptr;
        st_ql_dsp.ffCD = nullptr;
        st_ql_dsp.ffFJKG = nullptr;
        st_ql_dsp.ffH = nullptr;
        st_ql_dsp.ffO = nullptr;
        st_ql_dsp.mul = nullptr;
        st_ql_dsp.mux = nullptr;
        st_ql_dsp.muxAB = IdString();
        st_ql_dsp.o_lo = bool();
        st_ql_dsp.sigA = SigSpec();
        st_ql_dsp.sigB = SigSpec();
        st_ql_dsp.sigCD = SigSpec();
        st_ql_dsp.sigH = SigSpec();
        st_ql_dsp.sigO = SigSpec();
        block_0(1);
        log_assert(rollback_cache.empty());
        return accept_cnt;
    }

    int run_ql_dsp(std::function<void(ql_dsp_pm &)> on_accept_f)
    {
        return run_ql_dsp([&]() { on_accept_f(*this); });
    }

    int run_ql_dsp()
    {
        return run_ql_dsp([]() {});
    }

    void block_subpattern_ql_dsp_(int recursion) { block_0(recursion); }
    void block_subpattern_ql_dsp_in_dffe(int recursion) { block_15(recursion); }
    void block_subpattern_ql_dsp_out_dffe(int recursion) { block_19(recursion); }

    // passes/pmgen/ql_dsp.pmg:20
    void block_0(int recursion YS_MAYBE_UNUSED)
    {
        Cell *&mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;
        Cell *_pmg_backup_mul = mul;

        index_0_key_type key;
        auto cells_ptr = index_0.find(key);

        if (cells_ptr != index_0.end()) {
            const vector<index_0_value_type> &cells = cells_ptr->second;
            for (int _pmg_idx = 0; _pmg_idx < GetSize(cells); _pmg_idx++) {
                mul = std::get<0>(cells[_pmg_idx]);
                if (blacklist_cells.count(mul))
                    continue;
                auto rollback_ptr = rollback_cache.insert(make_pair(std::get<0>(cells[_pmg_idx]), recursion));
                block_1(recursion + 1);
                if (rollback_ptr.second)
                    rollback_cache.erase(rollback_ptr.first);
                if (rollback) {
                    if (rollback != recursion) {
                        mul = _pmg_backup_mul;
                        return;
                    }
                    rollback = 0;
                }
            }
        }

        mul = nullptr;
        mul = _pmg_backup_mul;
    }

    // passes/pmgen/ql_dsp.pmg:25
    void block_1(int recursion YS_MAYBE_UNUSED)
    {
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_2(recursion + 1);                                                                                                                      \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        auto unextend = [](const SigSpec &sig) {
            int i;
            for (i = GetSize(sig) - 1; i > 0; i--)
                if (sig[i] != sig[i - 1])
                    break;
            // Do not remove non-const sign bit
            if (sig[i].wire)
                ++i;
            return sig.extract(0, i);
        };
        sigA = unextend(port(mul, id_b_A));
        sigB = unextend(port(mul, id_b_B));
        SigSpec O;
        if (mul->type == id_d_mul)
            O = mul->getPort(id_b_Y);
        else if (mul->type == id_b_QL_DSP)
            O = mul->getPort(id_b_O);
        else
            log_abort();
        if (GetSize(O) <= 10)
            reject;
        // Only care about those bits that are used
        int i;
        for (i = 0; i < GetSize(O); i++) {
            if (nusers(O[i]) <= 1)
                break;
            sigH.append(O[i]);
        }
        // This sigM could have no users if downstream sinks (e.g. id_d_add) is
        //   narrower than id_d_mul result, for example
        if (i == 0)
            reject;
        log_assert(nusers(O.extract_end(i)) <= 1);

        block_2(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;

        sigA = SigSpec();
        sigB = SigSpec();
        sigH = SigSpec();
    }

    // passes/pmgen/ql_dsp.pmg:63
    void block_2(int recursion YS_MAYBE_UNUSED)
    {
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        const SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        const SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *&ffA YS_MAYBE_UNUSED = st_ql_dsp.ffA;
        SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

        SigSpec _pmg_backup_sigA = sigA;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_3(recursion + 1);                                                                                                                      \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        if (mul->type != id_b_QL_DSP || !param(mul, id_b_A_REG).as_bool()) {
            argQ = sigA;
            subpattern(in_dffe);
            if (dff) {
                ffA = dff;
                clock = dffclock;
                clock_pol = dffclock_pol;
                sigA = dffD;
            }
        }

        block_3(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;

        sigA = _pmg_backup_sigA;
        argQ = SigSpec();
        clock = SigBit();
        clock_pol = bool();
        ffA = nullptr;
    }

    // passes/pmgen/ql_dsp.pmg:76
    void block_3(int recursion YS_MAYBE_UNUSED)
    {
        Cell *const &ffA YS_MAYBE_UNUSED = st_ql_dsp.ffA;
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        const SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        const SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *&ffB YS_MAYBE_UNUSED = st_ql_dsp.ffB;
        SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

        SigSpec _pmg_backup_argQ = argQ;
        SigBit _pmg_backup_clock = clock;
        bool _pmg_backup_clock_pol = clock_pol;
        SigSpec _pmg_backup_sigB = sigB;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_4(recursion + 1);                                                                                                                      \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        if (mul->type != id_b_QL_DSP || !param(mul, id_b_B_REG).as_bool()) {
            argQ = sigB;
            subpattern(in_dffe);
            if (dff) {
                ffB = dff;
                clock = dffclock;
                clock_pol = dffclock_pol;
                sigB = dffD;
            }
        }

        block_4(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;

        argQ = _pmg_backup_argQ;
        clock = _pmg_backup_clock;
        clock_pol = _pmg_backup_clock_pol;
        sigB = _pmg_backup_sigB;
        ffB = nullptr;
    }

    // passes/pmgen/ql_dsp.pmg:89
    void block_4(int recursion YS_MAYBE_UNUSED)
    {
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        Cell *const &ffA YS_MAYBE_UNUSED = st_ql_dsp.ffA;
        Cell *const &ffB YS_MAYBE_UNUSED = st_ql_dsp.ffB;
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        const SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        const SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *&ffFJKG YS_MAYBE_UNUSED = st_ql_dsp.ffFJKG;
        SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

        SigBit _pmg_backup_clock = clock;
        bool _pmg_backup_clock_pol = clock_pol;
        SigSpec _pmg_backup_sigH = sigH;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_5(recursion + 1);                                                                                                                      \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        if (nusers(sigH) == 2 && (mul->type != id_b_QL_DSP)) {
            argD = sigH;
            argSdff = false;
            subpattern(out_dffe);
            if (dff) {
                // F/J/K/G do not have a CE-like (hold) input
                if (dff->hasPort(id_b_EN))
                    goto reject_ffFJKG;
                // Reset signal of F/J (IRSTTOP) and K/G (IRSTBOT)
                //   shared with A and B
                if (ffA) {
                    if (ffA->hasPort(id_b_ARST) != dff->hasPort(id_b_ARST))
                        goto reject_ffFJKG;
                    if (ffA->hasPort(id_b_ARST)) {
                        if (port(ffA, id_b_ARST) != port(dff, id_b_ARST))
                            goto reject_ffFJKG;
                        if (param(ffA, id_b_ARST_POLARITY) != param(dff, id_b_ARST_POLARITY))
                            goto reject_ffFJKG;
                    }
                }
                if (ffB) {
                    if (ffB->hasPort(id_b_ARST) != dff->hasPort(id_b_ARST))
                        goto reject_ffFJKG;
                    if (ffB->hasPort(id_b_ARST)) {
                        if (port(ffB, id_b_ARST) != port(dff, id_b_ARST))
                            goto reject_ffFJKG;
                        if (param(ffB, id_b_ARST_POLARITY) != param(dff, id_b_ARST_POLARITY))
                            goto reject_ffFJKG;
                    }
                }
                ffFJKG = dff;
                clock = dffclock;
                clock_pol = dffclock_pol;
                sigH = dffQ;
            reject_ffFJKG:;
            }
        }

        block_5(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;

        clock = _pmg_backup_clock;
        clock_pol = _pmg_backup_clock_pol;
        sigH = _pmg_backup_sigH;
        argD = SigSpec();
        argSdff = bool();
        ffFJKG = nullptr;
    }

    // passes/pmgen/ql_dsp.pmg:134
    void block_5(int recursion YS_MAYBE_UNUSED)
    {
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        Cell *const &ffA YS_MAYBE_UNUSED = st_ql_dsp.ffA;
        Cell *const &ffB YS_MAYBE_UNUSED = st_ql_dsp.ffB;
        Cell *const &ffFJKG YS_MAYBE_UNUSED = st_ql_dsp.ffFJKG;
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        const SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        const SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *&ffH YS_MAYBE_UNUSED = st_ql_dsp.ffH;
        SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        SigSpec &sigO YS_MAYBE_UNUSED = st_ql_dsp.sigO;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

        SigSpec _pmg_backup_argD = argD;
        bool _pmg_backup_argSdff = argSdff;
        SigBit _pmg_backup_clock = clock;
        bool _pmg_backup_clock_pol = clock_pol;
        SigSpec _pmg_backup_sigH = sigH;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_6(recursion + 1);                                                                                                                      \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        if (ffFJKG && nusers(sigH) == 2 && (mul->type != id_b_QL_DSP)) {
            argD = sigH;
            argSdff = false;
            subpattern(out_dffe);
            if (dff) {
                // H does not have a CE-like (hold) input
                if (dff->hasPort(id_b_EN))
                    goto reject_ffH;
                // Reset signal of H (IRSTBOT) shared with B
                if (ffB->hasPort(id_b_ARST) != dff->hasPort(id_b_ARST))
                    goto reject_ffH;
                if (ffB->hasPort(id_b_ARST)) {
                    if (port(ffB, id_b_ARST) != port(dff, id_b_ARST))
                        goto reject_ffH;
                    if (param(ffB, id_b_ARST_POLARITY) != param(dff, id_b_ARST_POLARITY))
                        goto reject_ffH;
                }
                ffH = dff;
                clock = dffclock;
                clock_pol = dffclock_pol;
                sigH = dffQ;
            reject_ffH:;
            }
        }
        sigO = sigH;

        block_6(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;

        argD = _pmg_backup_argD;
        argSdff = _pmg_backup_argSdff;
        clock = _pmg_backup_clock;
        clock_pol = _pmg_backup_clock_pol;
        sigH = _pmg_backup_sigH;
        ffH = nullptr;
        sigO = SigSpec();
    }

    // passes/pmgen/ql_dsp.pmg:167
    void block_6(int recursion YS_MAYBE_UNUSED)
    {
        const SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        const bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        const SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        const bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *const &ffA YS_MAYBE_UNUSED = st_ql_dsp.ffA;
        Cell *const &ffB YS_MAYBE_UNUSED = st_ql_dsp.ffB;
        Cell *const &ffFJKG YS_MAYBE_UNUSED = st_ql_dsp.ffFJKG;
        Cell *const &ffH YS_MAYBE_UNUSED = st_ql_dsp.ffH;
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        const SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        const SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        const SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        const SigSpec &sigO YS_MAYBE_UNUSED = st_ql_dsp.sigO;
        Cell *&add YS_MAYBE_UNUSED = st_ql_dsp.add;
        IdString &addAB YS_MAYBE_UNUSED = st_ql_dsp.addAB;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;
        Cell *_pmg_backup_add = add;

        if (!(mul->type != id_b_QL_DSP || (param(mul, id_b_ENABLE_DSP).as_int() == 1))) {
            add = nullptr;
            block_7(recursion + 1);
            add = _pmg_backup_add;
            return;
        }

        index_6_key_type key;
        std::get<0>(key) = sigH[0];
        auto cells_ptr = index_6.find(key);

        if (cells_ptr != index_6.end()) {
            const vector<index_6_value_type> &cells = cells_ptr->second;
            for (int _pmg_idx = 0; _pmg_idx < GetSize(cells); _pmg_idx++) {
                add = std::get<0>(cells[_pmg_idx]);
                const IdString &AB YS_MAYBE_UNUSED = std::get<1>(cells[_pmg_idx]);
                if (blacklist_cells.count(add))
                    continue;
                if (!(GetSize(port(add, AB)) <= GetSize(sigH)))
                    continue;
                if (!(port(add, AB) == sigH.extract(0, GetSize(port(add, AB)))))
                    continue;
                if (!(nusers(sigH.extract_end(GetSize(port(add, AB)))) <= 1))
                    continue;
                auto _pmg_backup_addAB = addAB;
                addAB = AB;
                auto rollback_ptr = rollback_cache.insert(make_pair(std::get<0>(cells[_pmg_idx]), recursion));
                block_7(recursion + 1);
                addAB = _pmg_backup_addAB;
                if (rollback_ptr.second)
                    rollback_cache.erase(rollback_ptr.first);
                if (rollback) {
                    if (rollback != recursion) {
                        add = _pmg_backup_add;
                        return;
                    }
                    rollback = 0;
                }
            }
        }

        add = nullptr;
        block_7(recursion + 1);
        add = _pmg_backup_add;
    }

    // passes/pmgen/ql_dsp.pmg:182
    void block_7(int recursion YS_MAYBE_UNUSED)
    {
        Cell *const &add YS_MAYBE_UNUSED = st_ql_dsp.add;
        const IdString &addAB YS_MAYBE_UNUSED = st_ql_dsp.addAB;
        const SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        const bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        const SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        const bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *const &ffA YS_MAYBE_UNUSED = st_ql_dsp.ffA;
        Cell *const &ffB YS_MAYBE_UNUSED = st_ql_dsp.ffB;
        Cell *const &ffFJKG YS_MAYBE_UNUSED = st_ql_dsp.ffFJKG;
        Cell *const &ffH YS_MAYBE_UNUSED = st_ql_dsp.ffH;
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        const SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        const SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        const SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        bool &cd_signed YS_MAYBE_UNUSED = st_ql_dsp.cd_signed;
        SigSpec &sigCD YS_MAYBE_UNUSED = st_ql_dsp.sigCD;
        SigSpec &sigO YS_MAYBE_UNUSED = st_ql_dsp.sigO;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

        SigSpec _pmg_backup_sigO = sigO;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_8(recursion + 1);                                                                                                                      \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        if (add) {
            sigCD = port(add, addAB == id_b_A ? id_b_B : id_b_A);
            cd_signed = param(add, addAB == id_b_A ? id_b_B_SIGNED : id_b_A_SIGNED).as_bool();
            int natural_mul_width = GetSize(sigA) + GetSize(sigB);
            int actual_mul_width = GetSize(sigH);
            int actual_acc_width = GetSize(sigCD);
            if ((actual_acc_width > actual_mul_width) && (natural_mul_width > actual_mul_width))
                reject;
            // If accumulator, check adder width and signedness
            if (sigCD == sigH && (actual_acc_width != actual_mul_width) &&
                (param(mul, id_b_A_SIGNED).as_bool() != param(add, id_b_A_SIGNED).as_bool()))
                reject;
            sigO = port(add, id_b_Y);
        }

        block_8(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;

        sigO = _pmg_backup_sigO;
        cd_signed = bool();
        sigCD = SigSpec();
    }

    // passes/pmgen/ql_dsp.pmg:201
    void block_8(int recursion YS_MAYBE_UNUSED)
    {
        Cell *const &add YS_MAYBE_UNUSED = st_ql_dsp.add;
        const IdString &addAB YS_MAYBE_UNUSED = st_ql_dsp.addAB;
        const SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        const bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        const bool &cd_signed YS_MAYBE_UNUSED = st_ql_dsp.cd_signed;
        const SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        const bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *const &ffA YS_MAYBE_UNUSED = st_ql_dsp.ffA;
        Cell *const &ffB YS_MAYBE_UNUSED = st_ql_dsp.ffB;
        Cell *const &ffFJKG YS_MAYBE_UNUSED = st_ql_dsp.ffFJKG;
        Cell *const &ffH YS_MAYBE_UNUSED = st_ql_dsp.ffH;
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        const SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        const SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        const SigSpec &sigCD YS_MAYBE_UNUSED = st_ql_dsp.sigCD;
        const SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        const SigSpec &sigO YS_MAYBE_UNUSED = st_ql_dsp.sigO;
        Cell *&mux YS_MAYBE_UNUSED = st_ql_dsp.mux;
        IdString &muxAB YS_MAYBE_UNUSED = st_ql_dsp.muxAB;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;
        Cell *_pmg_backup_mux = mux;

        index_8_key_type key;
        std::get<0>(key) = sigO;
        auto cells_ptr = index_8.find(key);

        if (cells_ptr != index_8.end()) {
            const vector<index_8_value_type> &cells = cells_ptr->second;
            for (int _pmg_idx = 0; _pmg_idx < GetSize(cells); _pmg_idx++) {
                mux = std::get<0>(cells[_pmg_idx]);
                const IdString &AB YS_MAYBE_UNUSED = std::get<1>(cells[_pmg_idx]);
                if (blacklist_cells.count(mux))
                    continue;
                auto _pmg_backup_muxAB = muxAB;
                muxAB = AB;
                auto rollback_ptr = rollback_cache.insert(make_pair(std::get<0>(cells[_pmg_idx]), recursion));
                block_9(recursion + 1);
                muxAB = _pmg_backup_muxAB;
                if (rollback_ptr.second)
                    rollback_cache.erase(rollback_ptr.first);
                if (rollback) {
                    if (rollback != recursion) {
                        mux = _pmg_backup_mux;
                        return;
                    }
                    rollback = 0;
                }
            }
        }

        mux = nullptr;
        block_9(recursion + 1);
        mux = _pmg_backup_mux;
    }

    // passes/pmgen/ql_dsp.pmg:210
    void block_9(int recursion YS_MAYBE_UNUSED)
    {
        Cell *const &add YS_MAYBE_UNUSED = st_ql_dsp.add;
        const IdString &addAB YS_MAYBE_UNUSED = st_ql_dsp.addAB;
        const SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        const bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        const bool &cd_signed YS_MAYBE_UNUSED = st_ql_dsp.cd_signed;
        const SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        const bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *const &ffA YS_MAYBE_UNUSED = st_ql_dsp.ffA;
        Cell *const &ffB YS_MAYBE_UNUSED = st_ql_dsp.ffB;
        Cell *const &ffFJKG YS_MAYBE_UNUSED = st_ql_dsp.ffFJKG;
        Cell *const &ffH YS_MAYBE_UNUSED = st_ql_dsp.ffH;
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        Cell *const &mux YS_MAYBE_UNUSED = st_ql_dsp.mux;
        const IdString &muxAB YS_MAYBE_UNUSED = st_ql_dsp.muxAB;
        const SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        const SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        const SigSpec &sigCD YS_MAYBE_UNUSED = st_ql_dsp.sigCD;
        const SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        SigSpec &sigO YS_MAYBE_UNUSED = st_ql_dsp.sigO;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

        SigSpec _pmg_backup_sigO = sigO;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_10(recursion + 1);                                                                                                                     \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        if (mux)
            sigO = port(mux, id_b_Y);

        block_10(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;

        sigO = _pmg_backup_sigO;
    }

    // passes/pmgen/ql_dsp.pmg:215
    void block_10(int recursion YS_MAYBE_UNUSED)
    {
        Cell *const &add YS_MAYBE_UNUSED = st_ql_dsp.add;
        const IdString &addAB YS_MAYBE_UNUSED = st_ql_dsp.addAB;
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        Cell *const &ffA YS_MAYBE_UNUSED = st_ql_dsp.ffA;
        Cell *const &ffB YS_MAYBE_UNUSED = st_ql_dsp.ffB;
        Cell *const &ffFJKG YS_MAYBE_UNUSED = st_ql_dsp.ffFJKG;
        Cell *const &ffH YS_MAYBE_UNUSED = st_ql_dsp.ffH;
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        Cell *const &mux YS_MAYBE_UNUSED = st_ql_dsp.mux;
        const IdString &muxAB YS_MAYBE_UNUSED = st_ql_dsp.muxAB;
        const SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        const SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        const SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        bool &cd_signed YS_MAYBE_UNUSED = st_ql_dsp.cd_signed;
        SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *&ffO YS_MAYBE_UNUSED = st_ql_dsp.ffO;
        bool &o_lo YS_MAYBE_UNUSED = st_ql_dsp.o_lo;
        SigSpec &sigCD YS_MAYBE_UNUSED = st_ql_dsp.sigCD;
        SigSpec &sigO YS_MAYBE_UNUSED = st_ql_dsp.sigO;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

        SigSpec _pmg_backup_argD = argD;
        bool _pmg_backup_argSdff = argSdff;
        bool _pmg_backup_cd_signed = cd_signed;
        SigBit _pmg_backup_clock = clock;
        bool _pmg_backup_clock_pol = clock_pol;
        SigSpec _pmg_backup_sigCD = sigCD;
        SigSpec _pmg_backup_sigO = sigO;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_11(recursion + 1);                                                                                                                     \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        if (mul->type != id_b_QL_DSP || (param(mul, id_b_ENABLE_DSP).as_int() != 0)) {
            dff = nullptr;
            // First try entire sigO
            if (nusers(sigO) == 2) {
                argD = sigO;
                argSdff = !mux;
                subpattern(out_dffe);
            }
            // Otherwise try just its least significant 16 bits
            if (!dff && GetSize(sigO) > 16) {
                argD = sigO.extract(0, 16);
                if (nusers(argD) == 2) {
                    argSdff = !mux;
                    subpattern(out_dffe);
                    o_lo = dff;
                }
            }
            if (dff) {
                ffO = dff;
                clock = dffclock;
                clock_pol = dffclock_pol;
                sigO.replace(sigO.extract(0, GetSize(dffQ)), dffQ);
            }
            // Loading value into output register is not
            //   supported unless using accumulator
            if (mux) {
                if (sigCD != sigO)
                    reject;
                sigCD = port(mux, muxAB == id_b_B ? id_b_A : id_b_B);
                cd_signed = add && param(add, id_b_A_SIGNED).as_bool() && param(add, id_b_B_SIGNED).as_bool();
            } else if (dff && dff->hasPort(id_b_SRST)) {
                if (sigCD != sigO)
                    reject;
                sigCD = param(dff, id_b_SRST_VALUE);
                cd_signed = add && param(add, id_b_A_SIGNED).as_bool() && param(add, id_b_B_SIGNED).as_bool();
            }
        }

        block_11(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;

        argD = _pmg_backup_argD;
        argSdff = _pmg_backup_argSdff;
        cd_signed = _pmg_backup_cd_signed;
        clock = _pmg_backup_clock;
        clock_pol = _pmg_backup_clock_pol;
        sigCD = _pmg_backup_sigCD;
        sigO = _pmg_backup_sigO;
        ffO = nullptr;
        o_lo = bool();
    }

    // passes/pmgen/ql_dsp.pmg:267
    void block_11(int recursion YS_MAYBE_UNUSED)
    {
        Cell *const &add YS_MAYBE_UNUSED = st_ql_dsp.add;
        const IdString &addAB YS_MAYBE_UNUSED = st_ql_dsp.addAB;
        const SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        const bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        const bool &cd_signed YS_MAYBE_UNUSED = st_ql_dsp.cd_signed;
        Cell *const &ffA YS_MAYBE_UNUSED = st_ql_dsp.ffA;
        Cell *const &ffB YS_MAYBE_UNUSED = st_ql_dsp.ffB;
        Cell *const &ffFJKG YS_MAYBE_UNUSED = st_ql_dsp.ffFJKG;
        Cell *const &ffH YS_MAYBE_UNUSED = st_ql_dsp.ffH;
        Cell *const &ffO YS_MAYBE_UNUSED = st_ql_dsp.ffO;
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        Cell *const &mux YS_MAYBE_UNUSED = st_ql_dsp.mux;
        const IdString &muxAB YS_MAYBE_UNUSED = st_ql_dsp.muxAB;
        const bool &o_lo YS_MAYBE_UNUSED = st_ql_dsp.o_lo;
        const SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        const SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        const SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        const SigSpec &sigO YS_MAYBE_UNUSED = st_ql_dsp.sigO;
        SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *&ffCD YS_MAYBE_UNUSED = st_ql_dsp.ffCD;
        SigSpec &sigCD YS_MAYBE_UNUSED = st_ql_dsp.sigCD;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

        SigSpec _pmg_backup_argQ = argQ;
        SigBit _pmg_backup_clock = clock;
        bool _pmg_backup_clock_pol = clock_pol;
        SigSpec _pmg_backup_sigCD = sigCD;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_12(recursion + 1);                                                                                                                     \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        if (!sigCD.empty() && sigCD != sigO &&
            (mul->type != id_b_QL_DSP || (!param(mul, id_b_C_REG).as_bool() && !param(mul, id_b_D_REG).as_bool()))) {
            argQ = sigCD;
            subpattern(in_dffe);
            if (dff) {
                // Reset signal of C (IRSTTOP) and D (IRSTBOT)
                //   shared with A and B
                if (ffA) {
                    if (ffA->hasPort(id_b_ARST) != dff->hasPort(id_b_ARST))
                        goto reject_ffCD;
                    if (ffA->hasPort(id_b_ARST)) {
                        if (port(ffA, id_b_ARST) != port(dff, id_b_ARST))
                            goto reject_ffCD;
                        if (param(ffA, id_b_ARST_POLARITY) != param(dff, id_b_ARST_POLARITY))
                            goto reject_ffCD;
                    }
                }
                if (ffB) {
                    if (ffB->hasPort(id_b_ARST) != dff->hasPort(id_b_ARST))
                        goto reject_ffCD;
                    if (ffB->hasPort(id_b_ARST)) {
                        if (port(ffB, id_b_ARST) != port(dff, id_b_ARST))
                            goto reject_ffCD;
                        if (param(ffB, id_b_ARST_POLARITY) != param(dff, id_b_ARST_POLARITY))
                            goto reject_ffCD;
                    }
                }
                ffCD = dff;
                clock = dffclock;
                clock_pol = dffclock_pol;
                sigCD = dffD;
            reject_ffCD:;
            }
        }

        block_12(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;

        argQ = _pmg_backup_argQ;
        clock = _pmg_backup_clock;
        clock_pol = _pmg_backup_clock_pol;
        sigCD = _pmg_backup_sigCD;
        ffCD = nullptr;
    }

    // passes/pmgen/ql_dsp.pmg:306
    void block_12(int recursion YS_MAYBE_UNUSED)
    {
        Cell *const &add YS_MAYBE_UNUSED = st_ql_dsp.add;
        const IdString &addAB YS_MAYBE_UNUSED = st_ql_dsp.addAB;
        const SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        const bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        const bool &cd_signed YS_MAYBE_UNUSED = st_ql_dsp.cd_signed;
        const SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        const bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *const &ffA YS_MAYBE_UNUSED = st_ql_dsp.ffA;
        Cell *const &ffB YS_MAYBE_UNUSED = st_ql_dsp.ffB;
        Cell *const &ffCD YS_MAYBE_UNUSED = st_ql_dsp.ffCD;
        Cell *const &ffFJKG YS_MAYBE_UNUSED = st_ql_dsp.ffFJKG;
        Cell *const &ffH YS_MAYBE_UNUSED = st_ql_dsp.ffH;
        Cell *const &ffO YS_MAYBE_UNUSED = st_ql_dsp.ffO;
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        Cell *const &mux YS_MAYBE_UNUSED = st_ql_dsp.mux;
        const IdString &muxAB YS_MAYBE_UNUSED = st_ql_dsp.muxAB;
        const bool &o_lo YS_MAYBE_UNUSED = st_ql_dsp.o_lo;
        const SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        const SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        const SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        const SigSpec &sigO YS_MAYBE_UNUSED = st_ql_dsp.sigO;
        SigSpec &sigCD YS_MAYBE_UNUSED = st_ql_dsp.sigCD;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

        SigSpec _pmg_backup_sigCD = sigCD;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_13(recursion + 1);                                                                                                                     \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        sigCD.extend_u0(32, cd_signed);

        block_13(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;

        sigCD = _pmg_backup_sigCD;
    }

    // passes/pmgen/ql_dsp.pmg:310
    void block_13(int recursion YS_MAYBE_UNUSED)
    {
        Cell *const &add YS_MAYBE_UNUSED = st_ql_dsp.add;
        const IdString &addAB YS_MAYBE_UNUSED = st_ql_dsp.addAB;
        const SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        const bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        const bool &cd_signed YS_MAYBE_UNUSED = st_ql_dsp.cd_signed;
        const SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        const bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *const &ffA YS_MAYBE_UNUSED = st_ql_dsp.ffA;
        Cell *const &ffB YS_MAYBE_UNUSED = st_ql_dsp.ffB;
        Cell *const &ffCD YS_MAYBE_UNUSED = st_ql_dsp.ffCD;
        Cell *const &ffFJKG YS_MAYBE_UNUSED = st_ql_dsp.ffFJKG;
        Cell *const &ffH YS_MAYBE_UNUSED = st_ql_dsp.ffH;
        Cell *const &ffO YS_MAYBE_UNUSED = st_ql_dsp.ffO;
        Cell *const &mul YS_MAYBE_UNUSED = st_ql_dsp.mul;
        Cell *const &mux YS_MAYBE_UNUSED = st_ql_dsp.mux;
        const IdString &muxAB YS_MAYBE_UNUSED = st_ql_dsp.muxAB;
        const bool &o_lo YS_MAYBE_UNUSED = st_ql_dsp.o_lo;
        const SigSpec &sigA YS_MAYBE_UNUSED = st_ql_dsp.sigA;
        const SigSpec &sigB YS_MAYBE_UNUSED = st_ql_dsp.sigB;
        const SigSpec &sigCD YS_MAYBE_UNUSED = st_ql_dsp.sigCD;
        const SigSpec &sigH YS_MAYBE_UNUSED = st_ql_dsp.sigH;
        const SigSpec &sigO YS_MAYBE_UNUSED = st_ql_dsp.sigO;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_14(recursion + 1);                                                                                                                     \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        accept;

        block_14(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;
    }

    void block_14(int recursion YS_MAYBE_UNUSED) {}

    // passes/pmgen/ql_dsp.pmg:319
    void block_15(int recursion YS_MAYBE_UNUSED)
    {
        const SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        const SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        const bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_16(recursion + 1);                                                                                                                     \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        dff = nullptr;
        if (argQ.empty())
            reject;
        for (auto c : argQ.chunks()) {
            if (!c.wire)
                reject;
            if (c.wire->get_bool_attribute(id_b_keep))
                reject;
            Const init = c.wire->attributes.at(id_b_init, State::Sx);
            if (!init.is_fully_undef() && !init.is_fully_zero())
                reject;
        }

        block_16(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;
    }

    // passes/pmgen/ql_dsp.pmg:334
    void block_16(int recursion YS_MAYBE_UNUSED)
    {
        const SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        const SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        const bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *&ff YS_MAYBE_UNUSED = st_ql_dsp.ff;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;
        Cell *_pmg_backup_ff = ff;

        index_16_key_type key;
        std::get<0>(key) = argQ[0];
        auto cells_ptr = index_16.find(key);

        if (cells_ptr != index_16.end()) {
            const vector<index_16_value_type> &cells = cells_ptr->second;
            for (int _pmg_idx = 0; _pmg_idx < GetSize(cells); _pmg_idx++) {
                ff = std::get<0>(cells[_pmg_idx]);
                const int &offset YS_MAYBE_UNUSED = std::get<1>(cells[_pmg_idx]);
                if (blacklist_cells.count(ff))
                    continue;
                if (!(GetSize(port(ff, id_b_Q)) >= offset + GetSize(argQ)))
                    continue;
                if (!(port(ff, id_b_Q).extract(offset, GetSize(argQ)) == argQ))
                    continue;
                auto rollback_ptr = rollback_cache.insert(make_pair(std::get<0>(cells[_pmg_idx]), recursion));
                block_17(recursion + 1);
                if (rollback_ptr.second)
                    rollback_cache.erase(rollback_ptr.first);
                if (rollback) {
                    if (rollback != recursion) {
                        ff = _pmg_backup_ff;
                        return;
                    }
                    rollback = 0;
                }
            }
        }

        ff = nullptr;
        ff = _pmg_backup_ff;
    }

    // passes/pmgen/ql_dsp.pmg:347
    void block_17(int recursion YS_MAYBE_UNUSED)
    {
        const SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        const bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *const &ff YS_MAYBE_UNUSED = st_ql_dsp.ff;
        SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

        SigSpec _pmg_backup_argD = argD;
        SigSpec _pmg_backup_argQ = argQ;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_18(recursion + 1);                                                                                                                     \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        {
            if (clock != SigBit()) {
                if (port(ff, id_b_CLK) != clock)
                    reject;
                if (param(ff, id_b_CLK_POLARITY).as_bool() != clock_pol)
                    reject;
            }
            SigSpec Q = port(ff, id_b_Q);
            dff = ff;
            dffclock = port(ff, id_b_CLK);
            dffclock_pol = param(ff, id_b_CLK_POLARITY).as_bool();
            dffD = argQ;
            argD = port(ff, id_b_D);
            argQ = Q;
            dffD.replace(argQ, argD);
        }

        block_18(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;

        argD = _pmg_backup_argD;
        argQ = _pmg_backup_argQ;
    }

    void block_18(int recursion YS_MAYBE_UNUSED) {}

    // passes/pmgen/ql_dsp.pmg:372
    void block_19(int recursion YS_MAYBE_UNUSED)
    {
        const SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        const bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        const SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        const bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_20(recursion + 1);                                                                                                                     \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        dff = nullptr;
        for (auto c : argD.chunks())
            if (c.wire->get_bool_attribute(id_b_keep))
                reject;

        block_20(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;
    }

    // passes/pmgen/ql_dsp.pmg:379
    void block_20(int recursion YS_MAYBE_UNUSED)
    {
        const SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        const SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        const bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        const SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        const bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *&ff YS_MAYBE_UNUSED = st_ql_dsp.ff;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;
        Cell *_pmg_backup_ff = ff;

        index_20_key_type key;
        std::get<0>(key) = argD[0];
        auto cells_ptr = index_20.find(key);

        if (cells_ptr != index_20.end()) {
            const vector<index_20_value_type> &cells = cells_ptr->second;
            for (int _pmg_idx = 0; _pmg_idx < GetSize(cells); _pmg_idx++) {
                ff = std::get<0>(cells[_pmg_idx]);
                const int &offset YS_MAYBE_UNUSED = std::get<1>(cells[_pmg_idx]);
                if (blacklist_cells.count(ff))
                    continue;
                if (!(argSdff || ff->type.in(id_d_dff, id_d_dffe)))
                    continue;
                if (!(GetSize(port(ff, id_b_D)) >= offset + GetSize(argD)))
                    continue;
                if (!(port(ff, id_b_D).extract(offset, GetSize(argD)) == argD))
                    continue;
                auto rollback_ptr = rollback_cache.insert(make_pair(std::get<0>(cells[_pmg_idx]), recursion));
                block_21(recursion + 1);
                if (rollback_ptr.second)
                    rollback_cache.erase(rollback_ptr.first);
                if (rollback) {
                    if (rollback != recursion) {
                        ff = _pmg_backup_ff;
                        return;
                    }
                    rollback = 0;
                }
            }
        }

        ff = nullptr;
        ff = _pmg_backup_ff;
    }

    // passes/pmgen/ql_dsp.pmg:394
    void block_21(int recursion YS_MAYBE_UNUSED)
    {
        const SigSpec &argD YS_MAYBE_UNUSED = st_ql_dsp.argD;
        const bool &argSdff YS_MAYBE_UNUSED = st_ql_dsp.argSdff;
        const SigBit &clock YS_MAYBE_UNUSED = st_ql_dsp.clock;
        const bool &clock_pol YS_MAYBE_UNUSED = st_ql_dsp.clock_pol;
        Cell *const &ff YS_MAYBE_UNUSED = st_ql_dsp.ff;
        SigSpec &argQ YS_MAYBE_UNUSED = st_ql_dsp.argQ;
        Cell *&dff YS_MAYBE_UNUSED = ud_ql_dsp.dff;
        SigSpec &dffD YS_MAYBE_UNUSED = ud_ql_dsp.dffD;
        SigSpec &dffQ YS_MAYBE_UNUSED = ud_ql_dsp.dffQ;
        SigBit &dffclock YS_MAYBE_UNUSED = ud_ql_dsp.dffclock;
        bool &dffclock_pol YS_MAYBE_UNUSED = ud_ql_dsp.dffclock_pol;

        SigSpec _pmg_backup_argQ = argQ;

#define reject                                                                                                                                       \
    do {                                                                                                                                             \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define accept                                                                                                                                       \
    do {                                                                                                                                             \
        accept_cnt++;                                                                                                                                \
        on_accept();                                                                                                                                 \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define finish                                                                                                                                       \
    do {                                                                                                                                             \
        rollback = -1;                                                                                                                               \
        goto rollback_label;                                                                                                                         \
    } while (0)
#define branch                                                                                                                                       \
    do {                                                                                                                                             \
        block_22(recursion + 1);                                                                                                                     \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
#define subpattern(pattern_name)                                                                                                                     \
    do {                                                                                                                                             \
        block_subpattern_ql_dsp_##pattern_name(recursion + 1);                                                                                       \
        if (rollback)                                                                                                                                \
            goto rollback_label;                                                                                                                     \
    } while (0)
        if (ff) {
            if (clock != SigBit()) {
                if (port(ff, id_b_CLK) != clock)
                    reject;
                if (param(ff, id_b_CLK_POLARITY).as_bool() != clock_pol)
                    reject;
            }
            SigSpec D = port(ff, id_b_D);
            SigSpec Q = port(ff, id_b_Q);
            argQ = argD;
            argQ.replace(D, Q);
            for (auto c : argQ.chunks()) {
                Const init = c.wire->attributes.at(id_b_init, State::Sx);
                if (!init.is_fully_undef() && !init.is_fully_zero())
                    reject;
            }
            dff = ff;
            dffQ = argQ;
            dffclock = port(ff, id_b_CLK);
            dffclock_pol = param(ff, id_b_CLK_POLARITY).as_bool();
        }

        block_22(recursion + 1);
#undef reject
#undef accept
#undef finish
#undef branch
#undef subpattern

    rollback_label:
        YS_MAYBE_UNUSED;

        argQ = _pmg_backup_argQ;
    }

    void block_22(int recursion YS_MAYBE_UNUSED) {}
};
